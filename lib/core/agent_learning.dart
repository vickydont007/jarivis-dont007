import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

enum TaskOutcome {
  success,
  failure,
  partial,
  timeout,
}

class TaskRecord {
  final String id;
  final String agentId;
  final String taskDescription;
  final List<String> toolsUsed;
  final TaskOutcome outcome;
  final String? error;
  final DateTime timestamp;
  final Duration duration;
  final Map<String, dynamic> metadata;

  TaskRecord({
    required this.id,
    required this.agentId,
    required this.taskDescription,
    required this.toolsUsed,
    required this.outcome,
    this.error,
    required this.timestamp,
    required this.duration,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agent_id': agentId,
      'task_description': taskDescription,
      'tools_used': jsonEncode(toolsUsed),
      'outcome': outcome.name,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'duration_ms': duration.inMilliseconds,
      'metadata': jsonEncode(metadata),
    };
  }

  factory TaskRecord.fromMap(Map<String, dynamic> map) {
    return TaskRecord(
      id: map['id'],
      agentId: map['agent_id'],
      taskDescription: map['task_description'],
      toolsUsed: List<String>.from(jsonDecode(map['tools_used'] ?? '[]')),
      outcome: TaskOutcome.values.firstWhere(
        (o) => o.name == map['outcome'],
        orElse: () => TaskOutcome.failure,
      ),
      error: map['error'],
      timestamp: DateTime.parse(map['timestamp']),
      duration: Duration(milliseconds: map['duration_ms'] ?? 0),
      metadata: jsonDecode(map['metadata'] ?? '{}'),
    );
  }
}

class AgentPerformance {
  final String agentId;
  final int totalTasks;
  final int successfulTasks;
  final int failedTasks;
  final int partialTasks;
  final Duration averageDuration;
  final List<String> commonTools;
  final double successRate;

  AgentPerformance({
    required this.agentId,
    required this.totalTasks,
    required this.successfulTasks,
    required this.failedTasks,
    required this.partialTasks,
    required this.averageDuration,
    required this.commonTools,
    required this.successRate,
  });
}

class AgentLearning {
  static Database? _database;
  final StreamController<TaskRecord> _recordController =
      StreamController<TaskRecord>.broadcast();

  Stream<TaskRecord> get recordStream => _recordController.stream;

  AgentLearning();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_learning.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_records(
            id TEXT PRIMARY KEY,
            agent_id TEXT NOT NULL,
            task_description TEXT NOT NULL,
            tools_used TEXT DEFAULT '[]',
            outcome TEXT NOT NULL,
            error TEXT,
            timestamp TEXT NOT NULL,
            duration_ms INTEGER DEFAULT 0,
            metadata TEXT DEFAULT '{}'
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_agent_id ON task_records(agent_id)
        ''');

        await db.execute('''
          CREATE INDEX idx_outcome ON task_records(outcome)
        ''');
      },
    );
  }

  Future<void> recordTask({
    required String agentId,
    required String taskDescription,
    required List<String> toolsUsed,
    required TaskOutcome outcome,
    String? error,
    required Duration duration,
    Map<String, dynamic> metadata = const {},
  }) async {
    final record = TaskRecord(
      id: const Uuid().v4(),
      agentId: agentId,
      taskDescription: taskDescription,
      toolsUsed: toolsUsed,
      outcome: outcome,
      error: error,
      timestamp: DateTime.now(),
      duration: duration,
      metadata: metadata,
    );

    final db = await database;
    await db.insert('task_records', record.toMap());
    _recordController.add(record);
  }

  Future<AgentPerformance> getPerformance(String agentId) async {
    final db = await database;
    final results = await db.query(
      'task_records',
      where: 'agent_id = ?',
      whereArgs: [agentId],
    );

    if (results.isEmpty) {
      return AgentPerformance(
        agentId: agentId,
        totalTasks: 0,
        successfulTasks: 0,
        failedTasks: 0,
        partialTasks: 0,
        averageDuration: Duration.zero,
        commonTools: [],
        successRate: 0.0,
      );
    }

    final records = results.map((map) => TaskRecord.fromMap(map)).toList();
    final successful = records.where((r) => r.outcome == TaskOutcome.success).length;
    final failed = records.where((r) => r.outcome == TaskOutcome.failure).length;
    final partial = records.where((r) => r.outcome == TaskOutcome.partial).length;

    final totalDuration = records.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.duration,
    );
    final avgDuration = totalDuration ~/ records.length;

    final toolCounts = <String, int>{};
    for (final record in records) {
      for (final tool in record.toolsUsed) {
        toolCounts[tool] = (toolCounts[tool] ?? 0) + 1;
      }
    }
    final sortedTools = toolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final commonTools = sortedTools.take(5).map((e) => e.key).toList();

    return AgentPerformance(
      agentId: agentId,
      totalTasks: records.length,
      successfulTasks: successful,
      failedTasks: failed,
      partialTasks: partial,
      averageDuration: avgDuration,
      commonTools: commonTools,
      successRate: successful / records.length,
    );
  }

  Future<Map<String, AgentPerformance>> getAllPerformance() async {
    final db = await database;
    final results = await db.rawQuery('SELECT DISTINCT agent_id FROM task_records');
    final agentIds = results.map((r) => r['agent_id'] as String).toList();

    final performances = <String, AgentPerformance>{};
    for (final id in agentIds) {
      performances[id] = await getPerformance(id);
    }
    return performances;
  }

  Future<List<TaskRecord>> getRecentRecords({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'task_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((map) => TaskRecord.fromMap(map)).toList();
  }

  Future<List<TaskRecord>> getFailedRecords({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'task_records',
      where: 'outcome = ?',
      whereArgs: [TaskOutcome.failure.name],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((map) => TaskRecord.fromMap(map)).toList();
  }

  Future<List<String>> getSuggestedImprovements(String agentId) async {
    final performance = await getPerformance(agentId);
    final suggestions = <String>[];

    if (performance.successRate < 0.7 && performance.totalTasks > 0) {
      suggestions.add('Success rate is low (${(performance.successRate * 100).toStringAsFixed(0)}%). Consider reviewing task approach.');
    }

    final failedRecords = await getFailedRecords(limit: 100);
    final agentFailed = failedRecords.where((r) => r.agentId == agentId).toList();

    final errorPatterns = <String, int>{};
    for (final record in agentFailed) {
      if (record.error != null) {
        final errorKey = record.error!.length > 50
            ? record.error!.substring(0, 50)
            : record.error!;
        errorPatterns[errorKey] = (errorPatterns[errorKey] ?? 0) + 1;
      }
    }

    for (final entry in errorPatterns.entries) {
      if (entry.value > 2) {
        suggestions.add('Recurring error: "${entry.key}" (occurred ${entry.value} times)');
      }
    }

    if (performance.averageDuration.inSeconds > 30) {
      suggestions.add('Average task duration is high (${performance.averageDuration.inSeconds}s). Consider optimizing.');
    }

    return suggestions;
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final total = await db.rawQuery('SELECT COUNT(*) as count FROM task_records');
    final successful = await db.rawQuery(
      "SELECT COUNT(*) as count FROM task_records WHERE outcome = 'success'"
    );
    final failed = await db.rawQuery(
      "SELECT COUNT(*) as count FROM task_records WHERE outcome = 'failure'"
    );
    final agents = await db.rawQuery('SELECT COUNT(DISTINCT agent_id) as count FROM task_records');

    final totalCount = (total.first['count'] as int?) ?? 0;
    final successCount = (successful.first['count'] as int?) ?? 0;
    final failedCount = (failed.first['count'] as int?) ?? 0;
    final agentCount = (agents.first['count'] as int?) ?? 0;

    return {
      'total_tasks': totalCount,
      'successful': successCount,
      'failed': failedCount,
      'success_rate': totalCount > 0 ? successCount / totalCount : 0.0,
      'unique_agents': agentCount,
    };
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('task_records');
  }

  void dispose() {
    _recordController.close();
  }
}
