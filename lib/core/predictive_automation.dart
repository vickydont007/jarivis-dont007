import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class AutomationPattern {
  final String id;
  final String name;
  final String description;
  final String trigger;
  final List<String> actions;
  final Map<String, dynamic> metadata;
  final int confidence;
  final DateTime createdAt;
  final DateTime lastUsed;
  final int useCount;

  AutomationPattern({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    required this.actions,
    this.metadata = const {},
    this.confidence = 0,
    required this.createdAt,
    required this.lastUsed,
    this.useCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trigger': trigger,
      'actions': jsonEncode(actions),
      'metadata': jsonEncode(metadata),
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
      'last_used': lastUsed.toIso8601String(),
      'use_count': useCount,
    };
  }

  factory AutomationPattern.fromMap(Map<String, dynamic> map) {
    return AutomationPattern(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      trigger: map['trigger'],
      actions: List<String>.from(jsonDecode(map['actions'] ?? '[]')),
      metadata: jsonDecode(map['metadata'] ?? '{}'),
      confidence: map['confidence'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      lastUsed: DateTime.parse(map['last_used']),
      useCount: map['use_count'] ?? 0,
    );
  }
}

class AutomationEvent {
  final String id;
  final String patternId;
  final String trigger;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final bool executed;

  AutomationEvent({
    required this.id,
    required this.patternId,
    required this.trigger,
    this.context = const {},
    required this.timestamp,
    this.executed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pattern_id': patternId,
      'trigger': trigger,
      'context': jsonEncode(context),
      'timestamp': timestamp.toIso8601String(),
      'executed': executed,
    };
  }

  factory AutomationEvent.fromMap(Map<String, dynamic> map) {
    return AutomationEvent(
      id: map['id'],
      patternId: map['pattern_id'],
      trigger: map['trigger'],
      context: jsonDecode(map['context'] ?? '{}'),
      timestamp: DateTime.parse(map['timestamp']),
      executed: map['executed'] ?? false,
    );
  }
}

class PredictiveAutomation {
  static Database? _database;
  final StreamController<AutomationPattern> _patternController =
      StreamController<AutomationPattern>.broadcast();

  Stream<AutomationPattern> get patternStream => _patternController.stream;

  PredictiveAutomation();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_automation.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE automation_patterns(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            trigger TEXT NOT NULL,
            actions TEXT NOT NULL,
            metadata TEXT DEFAULT '{}',
            confidence INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            last_used TEXT NOT NULL,
            use_count INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE automation_events(
            id TEXT PRIMARY KEY,
            pattern_id TEXT NOT NULL,
            trigger TEXT NOT NULL,
            context TEXT DEFAULT '{}',
            timestamp TEXT NOT NULL,
            executed INTEGER DEFAULT 0,
            FOREIGN KEY (pattern_id) REFERENCES automation_patterns(id)
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_trigger ON automation_patterns(trigger)
        ''');
      },
    );
  }

  Future<void> createPattern({
    required String name,
    required String description,
    required String trigger,
    required List<String> actions,
    Map<String, dynamic> metadata = const {},
    int confidence = 0,
  }) async {
    final pattern = AutomationPattern(
      id: const Uuid().v4(),
      name: name,
      description: description,
      trigger: trigger,
      actions: actions,
      metadata: metadata,
      confidence: confidence,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );

    final db = await database;
    await db.insert('automation_patterns', pattern.toMap());
    _patternController.add(pattern);
  }

  Future<List<AutomationPattern>> getPatternsByTrigger(String trigger) async {
    final db = await database;
    final results = await db.query(
      'automation_patterns',
      where: 'trigger = ?',
      whereArgs: [trigger],
      orderBy: 'confidence DESC, use_count DESC',
    );

    return results.map((map) => AutomationPattern.fromMap(map)).toList();
  }

  Future<List<AutomationPattern>> getAllPatterns() async {
    final db = await database;
    final results = await db.query(
      'automation_patterns',
      orderBy: 'confidence DESC, use_count DESC',
    );

    return results.map((map) => AutomationPattern.fromMap(map)).toList();
  }

  Future<void> recordEvent({
    required String patternId,
    required String trigger,
    Map<String, dynamic> context = const {},
    bool executed = false,
  }) async {
    final event = AutomationEvent(
      id: const Uuid().v4(),
      patternId: patternId,
      trigger: trigger,
      context: context,
      timestamp: DateTime.now(),
      executed: executed,
    );

    final db = await database;
    await db.insert('automation_events', event.toMap());

    await db.update(
      'automation_patterns',
      {
        'use_count': (await _getUseCount(patternId)) + 1,
        'last_used': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patternId],
    );
  }

  Future<int> _getUseCount(String patternId) async {
    final db = await database;
    final results = await db.query(
      'automation_patterns',
      columns: ['use_count'],
      where: 'id = ?',
      whereArgs: [patternId],
    );

    if (results.isEmpty) return 0;
    return results.first['use_count'] as int? ?? 0;
  }

  Future<void> updateConfidence(String patternId, int confidence) async {
    final db = await database;
    await db.update(
      'automation_patterns',
      {'confidence': confidence},
      where: 'id = ?',
      whereArgs: [patternId],
    );
  }

  Future<void> deletePattern(String patternId) async {
    final db = await database;
    await db.delete(
      'automation_events',
      where: 'pattern_id = ?',
      whereArgs: [patternId],
    );
    await db.delete(
      'automation_patterns',
      where: 'id = ?',
      whereArgs: [patternId],
    );
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final totalPatterns = await db.rawQuery('SELECT COUNT(*) as count FROM automation_patterns');
    final totalEvents = await db.rawQuery('SELECT COUNT(*) as count FROM automation_events');
    final executedEvents = await db.rawQuery(
      'SELECT COUNT(*) as count FROM automation_events WHERE executed = 1'
    );

    return {
      'total_patterns': (totalPatterns.first['count'] as int?) ?? 0,
      'total_events': (totalEvents.first['count'] as int?) ?? 0,
      'executed_events': (executedEvents.first['count'] as int?) ?? 0,
    };
  }

  void dispose() {
    _patternController.close();
  }
}
