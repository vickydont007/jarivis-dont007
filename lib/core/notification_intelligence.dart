import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class NotificationRule {
  final String id;
  final String name;
  final String description;
  final String sourceApp;
  final String pattern;
  final String action;
  final Map<String, dynamic> metadata;
  final bool enabled;
  final DateTime createdAt;
  final DateTime lastTriggered;
  final int triggerCount;

  NotificationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceApp,
    required this.pattern,
    required this.action,
    this.metadata = const {},
    this.enabled = true,
    required this.createdAt,
    required this.lastTriggered,
    this.triggerCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'source_app': sourceApp,
      'pattern': pattern,
      'action': action,
      'metadata': jsonEncode(metadata),
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_triggered': lastTriggered.toIso8601String(),
      'trigger_count': triggerCount,
    };
  }

  factory NotificationRule.fromMap(Map<String, dynamic> map) {
    return NotificationRule(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      sourceApp: map['source_app'],
      pattern: map['pattern'],
      action: map['action'],
      metadata: jsonDecode(map['metadata'] ?? '{}'),
      enabled: map['enabled'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      lastTriggered: DateTime.parse(map['last_triggered']),
      triggerCount: map['trigger_count'] ?? 0,
    );
  }
}

class NotificationEvent {
  final String id;
  final String? ruleId;
  final String sourceApp;
  final String title;
  final String body;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final bool processed;

  NotificationEvent({
    required this.id,
    this.ruleId,
    required this.sourceApp,
    required this.title,
    required this.body,
    this.metadata = const {},
    required this.timestamp,
    this.processed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rule_id': ruleId,
      'source_app': sourceApp,
      'title': title,
      'body': body,
      'metadata': jsonEncode(metadata),
      'timestamp': timestamp.toIso8601String(),
      'processed': processed ? 1 : 0,
    };
  }

  factory NotificationEvent.fromMap(Map<String, dynamic> map) {
    return NotificationEvent(
      id: map['id'],
      ruleId: map['rule_id'],
      sourceApp: map['source_app'],
      title: map['title'],
      body: map['body'],
      metadata: jsonDecode(map['metadata'] ?? '{}'),
      timestamp: DateTime.parse(map['timestamp']),
      processed: map['processed'] == 1,
    );
  }
}

class NotificationIntelligence {
  static Database? _database;
  final StreamController<NotificationEvent> _eventController =
      StreamController<NotificationEvent>.broadcast();

  Stream<NotificationEvent> get eventStream => _eventController.stream;

  NotificationIntelligence();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_notifications.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notification_rules(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            source_app TEXT NOT NULL,
            pattern TEXT NOT NULL,
            action TEXT NOT NULL,
            metadata TEXT DEFAULT '{}',
            enabled INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            last_triggered TEXT NOT NULL,
            trigger_count INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE notification_events(
            id TEXT PRIMARY KEY,
            rule_id TEXT,
            source_app TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            metadata TEXT DEFAULT '{}',
            timestamp TEXT NOT NULL,
            processed INTEGER DEFAULT 0,
            FOREIGN KEY (rule_id) REFERENCES notification_rules(id)
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_rules_source ON notification_rules(source_app)
        ''');

        await db.execute('''
          CREATE INDEX idx_events_timestamp ON notification_events(timestamp)
        ''');
      },
    );
  }

  Future<void> createRule({
    required String name,
    required String description,
    required String sourceApp,
    required String pattern,
    required String action,
    Map<String, dynamic> metadata = const {},
  }) async {
    final rule = NotificationRule(
      id: const Uuid().v4(),
      name: name,
      description: description,
      sourceApp: sourceApp,
      pattern: pattern,
      action: action,
      metadata: metadata,
      createdAt: DateTime.now(),
      lastTriggered: DateTime.now(),
    );

    final db = await database;
    await db.insert('notification_rules', rule.toMap());
  }

  Future<List<NotificationRule>> getRules({String? sourceApp}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (sourceApp != null) {
      whereClause = 'source_app = ?';
      whereArgs = [sourceApp];
    }

    final results = await db.query(
      'notification_rules',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return results.map((map) => NotificationRule.fromMap(map)).toList();
  }

  Future<void> recordEvent({
    required String sourceApp,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
    String? ruleId,
  }) async {
    final event = NotificationEvent(
      id: const Uuid().v4(),
      ruleId: ruleId,
      sourceApp: sourceApp,
      title: title,
      body: body,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    final db = await database;
    await db.insert('notification_events', event.toMap());
    _eventController.add(event);

    if (ruleId != null) {
      await db.update(
        'notification_rules',
        {
          'last_triggered': DateTime.now().toIso8601String(),
          'trigger_count': await _getTriggerCount(ruleId) + 1,
        },
        where: 'id = ?',
        whereArgs: [ruleId],
      );
    }
  }

  Future<int> _getTriggerCount(String ruleId) async {
    final db = await database;
    final results = await db.query(
      'notification_rules',
      columns: ['trigger_count'],
      where: 'id = ?',
      whereArgs: [ruleId],
    );

    if (results.isEmpty) return 0;
    return results.first['trigger_count'] as int? ?? 0;
  }

  Future<void> toggleRule(String ruleId, bool enabled) async {
    final db = await database;
    await db.update(
      'notification_rules',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [ruleId],
    );
  }

  Future<void> deleteRule(String ruleId) async {
    final db = await database;
    await db.delete(
      'notification_events',
      where: 'rule_id = ?',
      whereArgs: [ruleId],
    );
    await db.delete(
      'notification_rules',
      where: 'id = ?',
      whereArgs: [ruleId],
    );
  }

  Future<List<NotificationEvent>> getRecentEvents({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'notification_events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return results.map((map) => NotificationEvent.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final totalRules = await db.rawQuery('SELECT COUNT(*) as count FROM notification_rules');
    final enabledRules = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notification_rules WHERE enabled = 1'
    );
    final totalEvents = await db.rawQuery('SELECT COUNT(*) as count FROM notification_events');

    return {
      'total_rules': (totalRules.first['count'] as int?) ?? 0,
      'enabled_rules': (enabledRules.first['count'] as int?) ?? 0,
      'total_events': (totalEvents.first['count'] as int?) ?? 0,
    };
  }

  void dispose() {
    _eventController.close();
  }
}
