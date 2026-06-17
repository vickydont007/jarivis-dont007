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
import 'watchlist_monitor.dart';
import 'project_analyzer.dart';
import 'email_service.dart';
import 'calendar_intel.dart';
import 'external_knowledge.dart';
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
  final WatchlistMonitor _watchlistMonitor;
  final ProjectAnalyzer _projectAnalyzer;
  final EmailService _emailService;
  final CalendarIntel _calendarIntel;
  final ExternalKnowledge _externalKnowledge;

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
    required WatchlistMonitor watchlistMonitor,
    required ProjectAnalyzer projectAnalyzer,
    required EmailService emailService,
    required CalendarIntel calendarIntel,
    required ExternalKnowledge externalKnowledge,
  })  : _timeline = timeline,
        _memory = memory,
        _memorySearch = memorySearch,
        _orb = orb,
        _watchlistMonitor = watchlistMonitor,
        _projectAnalyzer = projectAnalyzer,
        _emailService = emailService,
        _calendarIntel = calendarIntel,
        _externalKnowledge = externalKnowledge;

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
      await _checkEmail();
      await _checkMeetingPrep();
      await _detectCrossLinks();
      _orb.releaseThinking('proactive');
    } catch (e) {
      _orb.releaseThinking('proactive');
    }
  }

  // ─── Watchlist Monitoring (Real Web Search) ───────────────────

  Future<void> _scanWatchlists() async {
    final watchlists = await _loadWatchlists();

    for (final entry in watchlists) {
      final articles = await _watchlistMonitor.searchTopic(entry.topic);

      if (articles.isNotEmpty) {
        // Store in external knowledge
        for (final article in articles) {
          await _externalKnowledge.ingest(
            type: 'article',
            title: article.title,
            content: article.summary,
            source: 'Watchlist:${entry.topic}',
            url: article.url,
            tags: [entry.topic, 'watchlist', 'web'],
          );

          // Generate insight
          final insight = Insight(
            id: 'watchlist_${article.url.hashCode}',
            type: InsightType.watchlist,
            priority: InsightPriority.medium,
            title: 'New article for "${entry.topic}": ${article.title}',
            body: article.summary.length > 200
                ? '${article.summary.substring(0, 200)}...'
                : article.summary,
            source: 'Watchlist Monitor',
            createdAt: DateTime.now(),
            metadata: {'topic': entry.topic, 'url': article.url},
          );
          await _addInsight(insight);
          await _watchlistMonitor.markAlerted(article.url);
        }
      }

      entry.lastChecked = DateTime.now();
      final count = await _watchlistMonitor.getArticleCount(entry.topic);
      entry.findingCount = count;
    }

    await _saveWatchlists(watchlists);
  }

  // ─── Project Analysis (Real Git Analysis) ────────────────────

  Future<void> _analyzeProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_projects');
    if (data == null) return;

    final projects = jsonDecode(data) as List;
    for (final project in projects) {
      final name = project['name'] as String? ?? '';
      final path = project['path'] as String? ?? '';
      if (path.isEmpty) continue;

      final result = await _projectAnalyzer.analyzeProject(name, path);

      // Store in external knowledge
      await _externalKnowledge.ingest(
        type: 'project',
        title: 'Project Analysis: $name',
        content: 'Framework: ${result.framework}\n'
            'Health: ${result.health} (${result.score}/100)\n'
            'Languages: ${result.languages.join(", ")}\n'
            'Dependencies: ${result.dependencies.join(", ")}\n'
            'Findings: ${result.findings.join(", ")}',
        source: 'Project Analyzer',
        tags: [name, 'project', result.health],
      );

      // Generate insight if health changed or new findings
      final lastScoreKey = 'project_score_$name';
      final lastScore = prefs.getInt(lastScoreKey) ?? 0;

      if (result.score != lastScore) {
        InsightPriority priority;
        if (result.health == 'Needs Attention' || result.health == 'Stalled') {
          priority = InsightPriority.high;
        } else {
          priority = InsightPriority.low;
        }

        await _addInsight(Insight(
          id: 'project_${name}_${DateTime.now().millisecondsSinceEpoch}',
          type: InsightType.project,
          priority: priority,
          title: '${result.health}: $name',
          body: 'Score: ${result.score}/100 — ${result.findings.isNotEmpty ? result.findings.first : "All good"}',
          source: 'Project Analyzer',
          createdAt: DateTime.now(),
          metadata: {'project': name, 'score': result.score, 'health': result.health},
        ));

        await prefs.setInt(lastScoreKey, result.score);
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

  // ─── Email Checking ──────────────────────────────────────────

  Future<void> _checkEmail() async {
    if (!_emailService.isConfigured) return;

    try {
      final emails = await _emailService.fetchEmails(unreadOnly: true, limit: 10);
      for (final email in emails) {
        // Store in external knowledge
        await _externalKnowledge.ingest(
          type: 'email',
          title: 'Email: ${email.subject}',
          content: 'From: ${email.from}\n${email.preview}',
          source: 'Email:${email.from}',
          tags: ['email', email.isMeeting ? 'meeting' : '', email.hasDeadline ? 'deadline' : '', email.isImportant ? 'important' : ''],
        );

        InsightPriority priority;
        if (email.isMeeting || email.hasDeadline) {
          priority = InsightPriority.urgent;
        } else if (email.isImportant) {
          priority = InsightPriority.high;
        } else {
          priority = InsightPriority.medium;
        }

        await _addInsight(Insight(
          id: 'email_${email.id}',
          type: InsightType.system,
          priority: priority,
          title: email.isMeeting
              ? '📅 Meeting: ${email.subject}'
              : email.hasDeadline
                  ? '⏰ Deadline: ${email.subject}'
                  : '📧 ${email.subject}',
          body: 'From: ${email.from}\n${email.preview.length > 100 ? "${email.preview.substring(0, 100)}..." : email.preview}',
          source: 'Email',
          createdAt: email.date,
          metadata: {
            'sender': email.from,
            'isMeeting': email.isMeeting,
            'hasDeadline': email.hasDeadline,
          },
        ));
      }
    } catch (e) {
      // Email check failed
    }
  }

  // ─── Meeting Prep (CalendarIntel) ─────────────────────────────

  Future<void> _checkMeetingPrep() async {
    try {
      final briefs = await _calendarIntel.checkUpcomingMeetings();
      for (final brief in briefs) {
        final key = 'meeting_${brief.meetingTitle}_${brief.meetingTime.millisecondsSinceEpoch}';
        if (_insights.any((i) => i.id == key)) continue;

        await _addInsight(Insight(
          id: key,
          type: InsightType.meeting,
          priority: InsightPriority.urgent,
          title: 'Meeting in ${brief.minutesUntil} min: ${brief.meetingTitle}',
          body: brief.contextSummary,
          source: 'Meeting Prep',
          createdAt: DateTime.now(),
          metadata: {
            'meetingTitle': brief.meetingTitle,
            'minutesUntil': brief.minutesUntil,
            'relatedMemories': brief.relatedMemories.length,
            'relatedEmails': brief.relatedEmails.length,
            'relatedProjects': brief.relatedProjects.length,
          },
        ));
      }
    } catch (e) {
      // Meeting prep check failed
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
