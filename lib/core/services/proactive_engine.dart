import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'timeline_service.dart';
import 'memory_service.dart';
import 'memory_search.dart';
import 'daily_briefing_service.dart';
import 'agent_manager.dart';
import 'orb_state_manager.dart';
import '../models/activity_event.dart';

enum InsightType { watchlist, project, meeting, system, crossLink }

enum InsightPriority { low, medium, high, urgent }

class Insight {
  final String id;
  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String body;
  final String source;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> metadata;

  Insight({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    required this.source,
    required this.createdAt,
    this.isRead = false,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'priority': priority.name,
    'title': title,
    'body': body,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'metadata': metadata,
  };

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
    id: json['id'],
    type: InsightType.values.firstWhere((t) => t.name == json['type']),
    priority: InsightPriority.values.firstWhere((p) => p.name == json['priority']),
    title: json['title'],
    body: json['body'],
    source: json['source'],
    createdAt: DateTime.parse(json['createdAt']),
    isRead: json['isRead'] ?? false,
    metadata: json['metadata'] ?? {},
  );
}

class WatchlistEntry {
  final String topic;
  final DateTime addedAt;
  DateTime? lastChecked;
  int findingCount;
  List<String> lastFindings;

  WatchlistEntry({
    required this.topic,
    required this.addedAt,
    this.lastChecked,
    this.findingCount = 0,
    this.lastFindings = const [],
  });

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'addedAt': addedAt.toIso8601String(),
    'lastChecked': lastChecked?.toIso8601String(),
    'findingCount': findingCount,
    'lastFindings': lastFindings,
  };

  factory WatchlistEntry.fromJson(Map<String, dynamic> json) => WatchlistEntry(
    topic: json['topic'],
    addedAt: DateTime.parse(json['addedAt']),
    lastChecked: json['lastChecked'] != null ? DateTime.parse(json['lastChecked']) : null,
    findingCount: json['findingCount'] ?? 0,
    lastFindings: List<String>.from(json['lastFindings'] ?? []),
  );
}

class ProjectInsight {
  final String projectName;
  final String insight;
  final String category;
  final DateTime detectedAt;

  ProjectInsight({
    required this.projectName,
    required this.insight,
    required this.category,
    required this.detectedAt,
  });
}

class ProactiveEngine {
  static Database? _database;
  static const _dbName = 'nextron_proactive_intel.db';

  final TimelineService _timeline;
  final MemoryService _memory;
  final MemorySearch _memorySearch;
  final OrbStateManager _orb;

  Timer? _monitorTimer;
  final StreamController<Insight> _insightController =
      StreamController<Insight>.broadcast();
  final List<Insight> _insights = [];

  Stream<Insight> get insightStream => _insightController.stream;
  List<Insight> get insights => List.unmodifiable(_insights);

  ProactiveEngine({
    required TimelineService timeline,
    required MemoryService memory,
    required MemorySearch memorySearch,
    required OrbStateManager orb,
  })  : _timeline = timeline,
        _memory = memory,
        _memorySearch = memorySearch,
        _orb = orb;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE insights(
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            priority TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            source TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_read INTEGER DEFAULT 0,
            metadata TEXT DEFAULT '{}'
          )
        ''');
      },
    );
  }

  Future<void> initialize() async {
    await database;
    await _loadInsights();
    _startMonitoring();
  }

  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      runCycle();
    });
    // Run first cycle after 30 seconds
    Timer(const Duration(seconds: 30), () => runCycle());
  }

  Future<void> runCycle() async {
    try {
      _orb.requestThinking('proactive');
      await _scanWatchlists();
      await _analyzeProjects();
      await _detectCrossLinks();
      await _checkMeetingPrep();
      _orb.releaseThinking('proactive');
    } catch (e) {
      _orb.releaseThinking('proactive');
    }
  }

  // ─── Watchlist Monitoring ──────────────────────────────────────

  Future<void> _scanWatchlists() async {
    final watchlists = await _loadWatchlists();
    final recentMemories = await _memory.recentMemories(limit: 50);

    for (final entry in watchlists) {
      final query = entry.topic.toLowerCase();
      final words = query.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

      final newFindings = <String>[];
      for (final memory in recentMemories) {
        final content = memory.content.toLowerCase();
        final matches = words.where((w) => content.contains(w)).length;
        if (matches >= (words.length * 0.5).ceil() && matches > 0) {
          if (!entry.lastFindings.contains(memory.content)) {
            newFindings.add(memory.content);
          }
        }
      }

      if (newFindings.isNotEmpty) {
        final insight = Insight(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: InsightType.watchlist,
          priority: InsightPriority.medium,
          title: 'New findings for "${entry.topic}"',
          body: '${newFindings.length} new match${newFindings.length > 1 ? 'es' : ''} found in your memories:\n${newFindings.take(3).map((f) => '• ${f.length > 80 ? f.substring(0, 80) + "..." : f}').join("\n")}',
          source: 'Watchlist',
          createdAt: DateTime.now(),
          metadata: {'topic': entry.topic, 'findingCount': newFindings.length},
        );
        await _addInsight(insight);
      }

      // Update watchlist entry
      entry.lastChecked = DateTime.now();
      entry.findingCount += newFindings.length;
      entry.lastFindings = [...newFindings, ...entry.lastFindings].take(10).toList();
    }

    await _saveWatchlists(watchlists);
  }

  // ─── Project Analysis ─────────────────────────────────────────

  Future<void> _analyzeProjects() async {
    final projects = await _loadProjects();

    for (final project in projects) {
      // Check timeline for project-related activity
      final recentEvents = await _timeline.getRecent(limit: 100);
      final projectEvents = recentEvents.where((e) =>
        e.description.toLowerCase().contains(project.name.toLowerCase()) ||
        e.metadata['project'] == project.name,
      ).toList();

      if (projectEvents.isEmpty) continue;

      // Analyze activity patterns
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final recentCount = projectEvents.where((e) =>
        e.timestamp.isAfter(lastWeek),
      ).length;

      final failedCount = projectEvents.where((e) =>
        e.type == ActivityType.agentFailed ||
        e.type == ActivityType.error,
      ).length;

      // Generate insights based on patterns
      if (recentCount == 0 && project.status == 'active') {
        await _addInsight(Insight(
          id: '${project.name}_inactive_${now.millisecondsSinceEpoch}',
          type: InsightType.project,
          priority: InsightPriority.low,
          title: '${project.name} has been quiet',
          body: 'No activity detected in the last 7 days. Consider reviewing or archiving.',
          source: 'Project Analyzer',
          createdAt: now,
          metadata: {'project': project.name},
        ));
      }

      if (failedCount > 3) {
        await _addInsight(Insight(
          id: '${project.name}_issues_${now.millisecondsSinceEpoch}',
          type: InsightType.project,
          priority: InsightPriority.high,
          title: 'Issues detected in ${project.name}',
          body: '$failedCount failures detected in recent activity. May need attention.',
          source: 'Project Analyzer',
          createdAt: now,
          metadata: {'project': project.name, 'failures': failedCount},
        ));
      }

      if (recentCount > 5) {
        await _addInsight(Insight(
          id: '${project.name}_active_${now.millisecondsSinceEpoch}',
          type: InsightType.project,
          priority: InsightPriority.low,
          title: '${project.name} is active',
          body: '$recentCount events in the last 7 days. Good momentum!',
          source: 'Project Analyzer',
          createdAt: now,
          metadata: {'project': project.name, 'events': recentCount},
        ));
      }
    }
  }

  // ─── Cross-Link Detection ─────────────────────────────────────

  Future<void> _detectCrossLinks() async {
    final memories = await _memory.recentMemories(limit: 30);
    final events = await _timeline.getRecent(limit: 30);

    // Find connections between memories and timeline events
    for (final memory in memories) {
      final memoryWords = memory.content.toLowerCase().split(RegExp(r'\s+'))
          .where((w) => w.length > 4).toSet();

      for (final event in events) {
        final eventWords = event.description.toLowerCase().split(RegExp(r'\s+'))
            .where((w) => w.length > 4).toSet();

        final overlap = memoryWords.intersection(eventWords);
        if (overlap.length >= 2) {
          final now = DateTime.now();
          final key = 'crosslink_${memory.id}_${event.id}';

          // Avoid duplicate cross-link insights
          if (_insights.any((i) => i.id.startsWith('crosslink_') &&
              i.metadata['memoryId'] == memory.id &&
              i.metadata['eventId'] == event.id)) continue;

          await _addInsight(Insight(
            id: key,
            type: InsightType.crossLink,
            priority: InsightPriority.low,
            title: 'Connection found',
            body: 'Memory "${memory.content.length > 40 ? memory.content.substring(0, 40) + "..." : memory.content}" relates to event "${event.title}"',
            source: 'Knowledge Hub',
            createdAt: now,
            metadata: {
              'memoryId': memory.id,
              'eventId': event.id,
              'memoryContent': memory.content,
              'eventTitle': event.title,
            },
          ));
        }
      }
    }
  }

  // ─── Meeting Prep ─────────────────────────────────────────────

  Future<void> _checkMeetingPrep() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('calendar_events');
    if (data == null) return;

    final events = jsonDecode(data) as List;
    final now = DateTime.now();

    for (final event in events) {
      final eventDate = DateTime.parse(event['date']);
      final diff = eventDate.difference(now);

      // Generate meeting prep 1 hour before
      if (diff.inMinutes > 0 && diff.inMinutes <= 60) {
        final key = 'meeting_${event['title']}_${eventDate.millisecondsSinceEpoch}';

        if (_insights.any((i) => i.id == key)) continue;

        // Search for related context
        final searchResults = await _memorySearch.search(event['title'], limit: 5);
        final contextSummary = searchResults.isNotEmpty
            ? searchResults.map((r) => '• ${r.content.length > 60 ? r.content.substring(0, 60) + "..." : r.content}').join('\n')
            : 'No related context found.';

        await _addInsight(Insight(
          id: key,
          type: InsightType.meeting,
          priority: InsightPriority.urgent,
          title: 'Meeting in ${diff.inMinutes} min: ${event['title']}',
          body: 'Preparation context:\n$contextSummary',
          source: 'Meeting Prep',
          createdAt: now,
          metadata: {
            'meetingTitle': event['title'],
            'minutesUntil': diff.inMinutes,
            'relatedMemories': searchResults.length,
          },
        ));
      }
    }
  }

  // ─── Insight Management ───────────────────────────────────────

  Future<void> _addInsight(Insight insight) async {
    // Deduplicate: skip if same title + source in last hour
    final recentDuplicate = _insights.any((i) =>
      i.title == insight.title &&
      i.source == insight.source &&
      i.createdAt.difference(insight.createdAt).abs() < const Duration(hours: 1),
    );
    if (recentDuplicate) return;

    _insights.insert(0, insight);
    if (_insights.length > 100) _insights.removeLast();

    _insightController.add(insight);

    final db = await database;
    await db.insert('insights', {
      'id': insight.id,
      'type': insight.type.name,
      'priority': insight.priority.name,
      'title': insight.title,
      'body': insight.body,
      'source': insight.source,
      'created_at': insight.createdAt.toIso8601String(),
      'is_read': insight.isRead ? 1 : 0,
      'metadata': jsonEncode(insight.metadata),
    });
  }

  Future<void> markInsightRead(String id) async {
    final index = _insights.indexWhere((i) => i.id == id);
    if (index == -1) return;

    final db = await database;
    await db.update('insights', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  List<Insight> getUnreadInsights() {
    return _insights.where((i) => !i.isRead).toList();
  }

  List<Insight> getInsightsByType(InsightType type) {
    return _insights.where((i) => i.type == type).toList();
  }

  List<Insight> getTopInsights({int limit = 5}) {
    final sorted = List<Insight>.from(_insights);
    sorted.sort((a, b) {
      final priorityOrder = {
        InsightPriority.urgent: 0,
        InsightPriority.high: 1,
        InsightPriority.medium: 2,
        InsightPriority.low: 3,
      };
      return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
    });
    return sorted.take(limit).toList();
  }

  // ─── Watchlist Persistence ────────────────────────────────────

  Future<List<WatchlistEntry>> _loadWatchlists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('research_watchlists');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => WatchlistEntry.fromJson(e)).toList();
  }

  Future<void> _saveWatchlists(List<WatchlistEntry> watchlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('research_watchlists',
        jsonEncode(watchlists.map((w) => w.toJson()).toList()));
  }

  // ─── Project Persistence ──────────────────────────────────────

  Future<List<_ProjectRef>> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_projects');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => _ProjectRef(
      name: e['name'],
      status: e['status'] ?? 'active',
    )).toList();
  }

  // ─── Insight Persistence ──────────────────────────────────────

  Future<void> _loadInsights() async {
    final db = await database;
    final results = await db.query('insights', orderBy: 'created_at DESC', limit: 50);
    _insights.clear();
    for (final row in results) {
      _insights.add(Insight.fromJson({
        'id': row['id'],
        'type': row['type'],
        'priority': row['priority'],
        'title': row['title'],
        'body': row['body'],
        'source': row['source'],
        'createdAt': row['created_at'],
        'isRead': (row['is_read'] as int) == 1,
        'metadata': jsonDecode(row['metadata'] as String? ?? '{}'),
      }));
    }
  }

  void dispose() {
    _monitorTimer?.cancel();
    _insightController.close();
  }
}

class _ProjectRef {
  final String name;
  final String status;
  _ProjectRef({required this.name, required this.status});
}
