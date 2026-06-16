import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/activity_event.dart';
import '../models/agent.dart';
import '../models/memory_record.dart';
import 'timeline_service.dart';
import 'agent_manager.dart';
import 'memory_service.dart';
import 'calendar_service.dart';
import 'email_service.dart';
import 'browser_service.dart';
import 'research_service.dart';
import 'multi_agent_orchestrator.dart';
import '../models/workflow.dart';
import '../calendar_event.dart';

enum BriefingType { morning, evening }

class DailyBriefingItem {
  final String icon;
  final String title;
  final String description;
  final String category;

  DailyBriefingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.category,
  });
}

class DailyBriefingReport {
  final DateTime date;
  final BriefingType type;
  final String greeting;
  final String summary;
  final List<DailyBriefingItem> items;
  final int totalEvents;
  final int completedTasks;
  final int failedTasks;
  final int newMemories;
  final int activeAgents;
  final int automationsRan;
  final String? moodSummary;
  final DateTime generatedAt;

  DailyBriefingReport({
    required this.date,
    required this.type,
    required this.greeting,
    required this.summary,
    required this.items,
    required this.totalEvents,
    required this.completedTasks,
    required this.failedTasks,
    required this.newMemories,
    required this.activeAgents,
    required this.automationsRan,
    this.moodSummary,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'type': type.name,
    'greeting': greeting,
    'summary': summary,
    'items': items.map((i) => {'icon': i.icon, 'title': i.title, 'description': i.description, 'category': i.category}).toList(),
    'totalEvents': totalEvents,
    'completedTasks': completedTasks,
    'failedTasks': failedTasks,
    'newMemories': newMemories,
    'activeAgents': activeAgents,
    'automationsRan': automationsRan,
    'moodSummary': moodSummary,
    'generatedAt': generatedAt.toIso8601String(),
  };
}

class DailyBriefingService {
  static Database? _database;
  static const _dbName = 'nextron_briefings.db';

  final TimelineService _timeline;
  final AgentManager _agents;
  final MemoryService _memory;
  final CalendarService? _calendarService;
  final EmailService? _emailService;
  final ResearchService? _researchService;
  final MultiAgentOrchestrator? _orchestrator;

  DailyBriefingService({
    required TimelineService timeline,
    required AgentManager agents,
    required MemoryService memory,
    CalendarService? calendarService,
    EmailService? emailService,
    ResearchService? researchService,
    MultiAgentOrchestrator? orchestrator,
  })  : _timeline = timeline,
        _agents = agents,
        _memory = memory,
        _calendarService = calendarService,
        _emailService = emailService,
        _researchService = researchService,
        _orchestrator = orchestrator;

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
          CREATE TABLE briefing_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            briefing_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<DailyBriefingReport> generateBriefing({BriefingType? type}) async {
    final now = DateTime.now();
    final briefingType = type ?? (now.hour < 12 ? BriefingType.morning : BriefingType.evening);

    final todayEvents = await _timeline.getTodayEvents();
    final allAgents = await _agents.getAllAgents();
    final recentTasks = await _agents.getRecentTasks(limit: 20);
    final allMemories = await _memory.getAll();

    final completedTasks = recentTasks.where((t) => t.isDone).length;
    final failedTasks = recentTasks.where((t) => t.hasFailed).length;
    final activeAgents = allAgents.where((a) => a.isActive).length;

    final items = <DailyBriefingItem>[];

    final agentStarted = todayEvents.where((e) => e.type == ActivityType.agentStarted).length;
    final agentCompleted = todayEvents.where((e) => e.type == ActivityType.agentCompleted).length;
    final agentFailed = todayEvents.where((e) => e.type == ActivityType.agentFailed).length;

    if (agentCompleted > 0) {
      items.add(DailyBriefingItem(
        icon: '🤖',
        title: '$agentCompleted agent task${agentCompleted > 1 ? 's' : ''} completed',
        description: '$agentCompleted of $agentStarted tasks finished successfully',
        category: 'agents',
      ));
    }

    if (agentFailed > 0) {
      items.add(DailyBriefingItem(
        icon: '⚠️',
        title: '$agentFailed task${agentFailed > 1 ? 's' : ''} failed',
        description: 'Some agent tasks encountered errors',
        category: 'agents',
      ));
    }

    final memoryCreated = todayEvents.where((e) => e.type == ActivityType.memoryCreated).length;
    final memoryUpdated = todayEvents.where((e) => e.type == ActivityType.memoryUpdated).length;
    if (memoryCreated > 0) {
      items.add(DailyBriefingItem(
        icon: '🧠',
        title: '$memoryCreated new memories stored',
        description: 'Your AI learned $memoryCreated new things today',
        category: 'memory',
      ));
    }
    if (memoryUpdated > 0) {
      items.add(DailyBriefingItem(
        icon: '🔄',
        title: '$memoryUpdated memories refined',
        description: 'Existing memories were updated with new context',
        category: 'memory',
      ));
    }

    final automationEvents = todayEvents.where((e) => e.type == ActivityType.automationExecuted).length;
    if (automationEvents > 0) {
      items.add(DailyBriefingItem(
        icon: '⚡',
        title: '$automationEvents automations executed',
        description: 'Scheduled workflows ran automatically',
        category: 'automation',
      ));
    }

    final toolUsed = todayEvents.where((e) => e.type == ActivityType.toolUsed).length;
    if (toolUsed > 0) {
      items.add(DailyBriefingItem(
        icon: '🔧',
        title: '$toolUsed tools invoked',
        description: 'File, web, and system operations performed',
        category: 'tools',
      ));
    }

    final errors = todayEvents.where((e) => e.type == ActivityType.error).length;
    if (errors > 0) {
      items.add(DailyBriefingItem(
        icon: '❌',
        title: '$errors error${errors > 1 ? 's' : ''} encountered',
        description: 'Some operations failed during execution',
        category: 'errors',
      ));
    }

    // Calendar events in briefing
    if (_calendarService != null) {
      try {
        final todayCalendarEvents = await _calendarService!.getTodayEvents();
        final upcomingEvents = await _calendarService!.getUpcomingEvents(limit: 5);

        if (todayCalendarEvents.isNotEmpty) {
          items.add(DailyBriefingItem(
            icon: '📅',
            title: '${todayCalendarEvents.length} event${todayCalendarEvents.length > 1 ? 's' : ''} today',
            description: todayCalendarEvents.map((e) => e.isAllDay ? e.title : '${e.title} at ${e.startTimeStr}').join('; '),
            category: 'calendar',
          ));
        }

        final tomorrowEvents = await _calendarService!.getTomorrowEvents();
        if (tomorrowEvents.isNotEmpty) {
          items.add(DailyBriefingItem(
            icon: '📆',
            title: '${tomorrowEvents.length} event${tomorrowEvents.length > 1 ? 's' : ''} tomorrow',
            description: tomorrowEvents.map((e) => e.isAllDay ? e.title : '${e.title} at ${e.startTimeStr}').join('; '),
            category: 'calendar',
          ));
        }

        // Reminders for upcoming events within 2 hours
        final now = DateTime.now();
        final soonEvents = todayCalendarEvents.where((e) {
          final diff = e.startTime.difference(now);
          return diff.inMinutes > 0 && diff.inMinutes <= 120;
        }).toList();

        for (final event in soonEvents) {
          final mins = event.startTime.difference(now).inMinutes;
          items.add(DailyBriefingItem(
            icon: '⏰',
            title: '${event.title} in $mins minutes',
            description: 'Upcoming at ${event.startTimeStr}${event.location.isNotEmpty ? " at ${event.location}" : ""}',
            category: 'calendar',
          ));
        }
      } catch (_) {}
    }

    // Email briefing
    if (_emailService != null) {
      try {
        final emailStats = await _emailService!.getEmailStats();
        final unread = emailStats['unread'] as int? ?? 0;
        final meetings = emailStats['meetings'] as int? ?? 0;
        final deadlines = emailStats['deadlines'] as int? ?? 0;
        final important = emailStats['important'] as int? ?? 0;

        if (unread > 0) {
          items.add(DailyBriefingItem(
            icon: '📧',
            title: '$unread unread email${unread > 1 ? "s" : ""}',
            description: '$unread new email${unread > 1 ? "s" : ""} in your inbox',
            category: 'email',
          ));
        }

        if (important > 0) {
          items.add(DailyBriefingItem(
            icon: '⭐',
            title: '$important important email${important > 1 ? "s" : ""}',
            description: 'Important emails require your attention',
            category: 'email',
          ));
        }

        if (meetings > 0) {
          items.add(DailyBriefingItem(
            icon: '📅',
            title: '$meetings meeting-related email${meetings > 1 ? "s" : ""}',
            description: 'Emails containing meeting invites or references',
            category: 'email',
          ));
        }

        if (deadlines > 0) {
          items.add(DailyBriefingItem(
            icon: '⏰',
            title: '$deadlines email${deadlines > 1 ? "s" : ""} with deadlines',
            description: 'Emails with deadline references need attention',
            category: 'email',
          ));
        }
      } catch (_) {}
    }

    // Research activity in briefing
    if (_researchService != null) {
      try {
        final recentReports = await _researchService!.getRecentReports(limit: 5);
        if (recentReports.isNotEmpty) {
          items.add(DailyBriefingItem(
            icon: '🔬',
            title: '${recentReports.length} research report${recentReports.length > 1 ? "s" : ""} generated',
            description: recentReports.map((r) => r.topic).join('; '),
            category: 'research',
          ));
        }
      } catch (_) {}
    }

    // Workflow status in briefing
    if (_orchestrator != null) {
      try {
        final active = await _orchestrator!.getActiveWorkflows();
        final failed = await _orchestrator!.getWorkflowsByStatus(WorkflowStatus.failed);

        if (active.isNotEmpty) {
          items.add(DailyBriefingItem(
            icon: '🔄',
            title: '${active.length} active workflow${active.length > 1 ? 's' : ''}',
            description: active.map((w) => w.goal).take(3).join('; '),
            category: 'orchestrator',
          ));
        }

        if (failed.isNotEmpty) {
          items.add(DailyBriefingItem(
            icon: '⚠️',
            title: '${failed.length} failed workflow${failed.length > 1 ? 's' : ''}',
            description: 'Some complex goals encountered errors',
            category: 'orchestrator',
          ));
        }
      } catch (_) {}
    }

    if (items.isEmpty) {
      if (briefingType == BriefingType.morning) {
        items.add(DailyBriefingItem(
          icon: '🌅',
          title: 'Fresh start',
          description: 'No activity yet today. Ready when you are.',
          category: 'general',
        ));
      } else {
        items.add(DailyBriefingItem(
          icon: '🌙',
          title: 'Quiet day',
          description: 'No significant activity recorded today.',
          category: 'general',
        ));
      }
    }

    final greeting = briefingType == BriefingType.morning
        ? _getMorningGreeting(now)
        : _getEveningGreeting(now);

    final summary = _buildSummary(items, briefingType);

    final report = DailyBriefingReport(
      date: now,
      type: briefingType,
      greeting: greeting,
      summary: summary,
      items: items,
      totalEvents: todayEvents.length,
      completedTasks: completedTasks,
      failedTasks: failedTasks,
      newMemories: memoryCreated,
      activeAgents: activeAgents,
      automationsRan: automationEvents,
      moodSummary: _getMoodSummary(todayEvents),
      generatedAt: now,
    );

    await _saveBriefing(report);
    return report;
  }

  String _getMorningGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 6) return 'Burning the midnight oil? Here\'s your report.';
    if (hour < 9) return 'Good morning! Here\'s what happened overnight.';
    if (hour < 12) return 'Good morning! Let me bring you up to speed.';
    return 'Good day! Here\'s your activity summary.';
  }

  String _getEveningGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 18) return 'Good afternoon! Here\'s how your day is going.';
    if (hour < 21) return 'Good evening! Here\'s your daily recap.';
    return 'Good night! Here\'s what happened today.';
  }

  String _buildSummary(List<DailyBriefingItem> items, BriefingType type) {
    final categories = items.map((i) => i.category).toSet();
    final parts = <String>[];

    if (categories.contains('agents')) {
      final agentItems = items.where((i) => i.category == 'agents').toList();
      parts.add('${agentItems.length} agent activity');
    }
    if (categories.contains('memory')) {
      parts.add('memory updates');
    }
    if (categories.contains('automation')) {
      parts.add('automations ran');
    }
    if (categories.contains('errors')) {
      final errCount = items.where((i) => i.category == 'errors').length;
      parts.add('$errCount error${errCount > 1 ? 's' : ''}');
    }

    if (parts.isEmpty) return 'All quiet on the system front.';
    return '${type == BriefingType.morning ? "Overnight" : "Today"}: ${parts.join(", ")}.';
  }

  String? _getMoodSummary(List<ActivityEvent> events) {
    final hasFailed = events.any((e) => e.type == ActivityType.agentFailed);
    final hasErrors = events.any((e) => e.type == ActivityType.error);
    final hasCompleted = events.any((e) => e.type == ActivityType.agentCompleted);
    final hasMemory = events.any((e) => e.type == ActivityType.memoryCreated);

    if (hasFailed || hasErrors) return 'Some hiccups today, but mostly on track.';
    if (hasCompleted && hasMemory) return 'Highly productive — learning and executing.';
    if (hasCompleted) return 'Active and productive.';
    if (hasMemory) return 'Quiet but learning.';
    return 'Steady and calm.';
  }

  Future<void> _saveBriefing(DailyBriefingReport report) async {
    final db = await database;
    await db.insert('briefing_history', {
      'date': report.date.toIso8601String(),
      'type': report.type.name,
      'briefing_json': jsonEncode(report.toJson()),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<DailyBriefingReport?> getLatestBriefing({BriefingType? type}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (type != null) {
      where = 'type = ?';
      whereArgs = [type.name];
    }
    final results = await db.query(
      'briefing_history',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    final json = jsonDecode(results.first['briefing_json'] as String);
    return _reportFromJson(json);
  }

  Future<List<DailyBriefingReport>> getBriefingHistory({int limit = 7}) async {
    final db = await database;
    final results = await db.query(
      'briefing_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((r) => _reportFromJson(jsonDecode(r['briefing_json'] as String))).toList();
  }

  DailyBriefingReport _reportFromJson(Map<String, dynamic> json) {
    return DailyBriefingReport(
      date: DateTime.parse(json['date']),
      type: BriefingType.values.firstWhere((t) => t.name == json['type']),
      greeting: json['greeting'],
      summary: json['summary'],
      items: (json['items'] as List).map((i) => DailyBriefingItem(
        icon: i['icon'],
        title: i['title'],
        description: i['description'],
        category: i['category'],
      )).toList(),
      totalEvents: json['totalEvents'],
      completedTasks: json['completedTasks'],
      failedTasks: json['failedTasks'],
      newMemories: json['newMemories'],
      activeAgents: json['activeAgents'],
      automationsRan: json['automationsRan'],
      moodSummary: json['moodSummary'],
      generatedAt: DateTime.parse(json['generatedAt']),
    );
  }
}
