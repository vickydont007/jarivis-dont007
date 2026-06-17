import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workflow.dart';
import '../services/agent_message_bus.dart';
import '../../tools/tool_manager.dart';

class WorkflowDatabase {
  static Database? _database;
  static const _dbName = 'nextron_workflows.db';
  String _currentUserId = '';

  void setUserId(String id) {
    _currentUserId = id;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workflow_executions(
            id TEXT PRIMARY KEY,
            goal TEXT NOT NULL,
            description TEXT,
            status TEXT NOT NULL,
            progress REAL DEFAULT 0,
            context TEXT,
            error_message TEXT,
            memory_tags TEXT,
            created_at TEXT NOT NULL,
            started_at TEXT,
            completed_at TEXT,
            user_id TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE workflow_tasks(
            id TEXT PRIMARY KEY,
            workflow_id TEXT NOT NULL,
            agent_type TEXT NOT NULL,
            tool_name TEXT NOT NULL,
            description TEXT,
            parameters TEXT,
            depends_on TEXT,
            priority INTEGER DEFAULT 0,
            max_retries INTEGER DEFAULT 2,
            timeout_seconds INTEGER DEFAULT 300,
            status TEXT NOT NULL,
            result TEXT,
            error TEXT,
            retry_count INTEGER DEFAULT 0,
            output_keys TEXT,
            started_at TEXT,
            completed_at TEXT,
            user_id TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (workflow_id) REFERENCES workflow_executions(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE agent_messages(
            id TEXT PRIMARY KEY,
            workflow_id TEXT NOT NULL,
            message_type TEXT NOT NULL,
            task_id TEXT,
            agent_type TEXT,
            data TEXT,
            timestamp TEXT NOT NULL,
            user_id TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (workflow_id) REFERENCES workflow_executions(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try { await db.execute("ALTER TABLE workflow_executions ADD COLUMN user_id TEXT NOT NULL DEFAULT ''"); } catch (_) {}
          try { await db.execute("ALTER TABLE workflow_tasks ADD COLUMN user_id TEXT NOT NULL DEFAULT ''"); } catch (_) {}
          try { await db.execute("ALTER TABLE agent_messages ADD COLUMN user_id TEXT NOT NULL DEFAULT ''"); } catch (_) {}
        }
      },
    );
  }

  Future<void> saveWorkflow(Workflow workflow) async {
    final db = await database;
    await db.insert('workflow_executions', {
      'id': workflow.id,
      'goal': workflow.goal,
      'description': workflow.description,
      'status': workflow.status.name,
      'progress': workflow.progress,
      'context': jsonEncode(workflow.context),
      'error_message': workflow.errorMessage,
      'memory_tags': jsonEncode(workflow.memoryTags),
      'created_at': workflow.createdAt.toIso8601String(),
      'started_at': workflow.startedAt?.toIso8601String(),
      'completed_at': workflow.completedAt?.toIso8601String(),
      'user_id': _currentUserId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (final task in workflow.tasks) {
      await db.insert('workflow_tasks', {
        'id': task.id,
        'workflow_id': workflow.id,
        'agent_type': task.agentType,
        'tool_name': task.toolName,
        'description': task.description,
        'parameters': jsonEncode(task.parameters),
        'depends_on': jsonEncode(task.dependsOn),
        'priority': task.priority,
        'max_retries': task.maxRetries,
        'timeout_seconds': task.timeout.inSeconds,
        'status': task.status.name,
        'result': task.result,
        'error': task.error,
        'retry_count': task.retryCount,
        'output_keys': jsonEncode(task.outputKeys),
        'started_at': task.startedAt?.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> updateWorkflow(Workflow workflow) async {
    final db = await database;
    await db.update('workflow_executions', {
      'status': workflow.status.name,
      'progress': workflow.progress,
      'error_message': workflow.errorMessage,
      'started_at': workflow.startedAt?.toIso8601String(),
      'completed_at': workflow.completedAt?.toIso8601String(),
    }, where: 'id = ?', whereArgs: [workflow.id]);

    for (final task in workflow.tasks) {
      await db.update('workflow_tasks', {
        'status': task.status.name,
        'result': task.result,
        'error': task.error,
        'retry_count': task.retryCount,
        'started_at': task.startedAt?.toIso8601String(),
        'completed_at': task.completedAt?.toIso8601String(),
      }, where: 'id = ?', whereArgs: [task.id]);
    }
  }

  Future<void> updateTask(WorkflowTask task) async {
    final db = await database;
    await db.update('workflow_tasks', {
      'status': task.status.name,
      'result': task.result,
      'error': task.error,
      'retry_count': task.retryCount,
      'started_at': task.startedAt?.toIso8601String(),
      'completed_at': task.completedAt?.toIso8601String(),
    }, where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> saveMessage(WorkflowMessage message) async {
    final db = await database;
    await db.insert('agent_messages', {
      'id': message.id,
      'workflow_id': message.workflowId,
      'message_type': message.type.name,
      'task_id': message.taskId,
      'agent_type': message.agentType,
      'data': message.data != null ? jsonEncode(message.data) : null,
      'timestamp': message.timestamp.toIso8601String(),
    });
  }

  Future<Workflow?> getWorkflow(String id) async {
    final db = await database;
    final rows = await db.query('workflow_executions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    final taskRows = await db.query('workflow_tasks', where: 'workflow_id = ?', whereArgs: [id], orderBy: 'priority ASC');

    final row = rows.first;
    return Workflow(
      id: row['id'] as String,
      goal: row['goal'] as String,
      description: row['description'] as String?,
      status: WorkflowStatus.values.firstWhere((s) => s.name == row['status'], orElse: () => WorkflowStatus.pending),
      createdAt: DateTime.parse(row['created_at'] as String),
      startedAt: row['started_at'] != null ? DateTime.parse(row['started_at'] as String) : null,
      completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
      tasks: taskRows.map((t) => WorkflowTask(
        id: t['id'] as String,
        agentType: t['agent_type'] as String,
        toolName: t['tool_name'] as String,
        description: t['description'] as String? ?? '',
        parameters: Map<String, dynamic>.from(jsonDecode(t['parameters'] as String? ?? '{}')),
        dependsOn: List<String>.from(jsonDecode(t['depends_on'] as String? ?? '[]')),
        priority: t['priority'] as int? ?? 0,
        maxRetries: t['max_retries'] as int? ?? 2,
        timeout: Duration(seconds: t['timeout_seconds'] as int? ?? 300),
        status: TaskStatus.values.firstWhere((s) => s.name == t['status'], orElse: () => TaskStatus.pending),
        result: t['result'] as String?,
        error: t['error'] as String?,
        retryCount: t['retry_count'] as int? ?? 0,
        outputKeys: List<String>.from(jsonDecode(t['output_keys'] as String? ?? '[]')),
        startedAt: t['started_at'] != null ? DateTime.parse(t['started_at'] as String) : null,
        completedAt: t['completed_at'] != null ? DateTime.parse(t['completed_at'] as String) : null,
      )).toList(),
      context: Map<String, dynamic>.from(jsonDecode(row['context'] as String? ?? '{}')),
      errorMessage: row['error_message'] as String?,
      memoryTags: List<String>.from(jsonDecode(row['memory_tags'] as String? ?? '[]')),
    );
  }

  Future<List<Workflow>> getWorkflows({int limit = 20, WorkflowStatus? status}) async {
    final db = await database;
    String? where = 'user_id = ?';
    List<dynamic> whereArgs = [_currentUserId];
    if (status != null) {
      where = 'user_id = ? AND status = ?';
      whereArgs = [_currentUserId, status.name];
    }
    final rows = await db.query('workflow_executions', where: where, whereArgs: whereArgs, orderBy: 'created_at DESC', limit: limit);

    final workflows = <Workflow>[];
    for (final row in rows) {
      final wf = await getWorkflow(row['id'] as String);
      if (wf != null) workflows.add(wf);
    }
    return workflows;
  }

  Future<List<Map<String, dynamic>>> getMessages(String workflowId) async {
    final db = await database;
    return await db.query('agent_messages', where: 'workflow_id = ?', whereArgs: [workflowId], orderBy: 'timestamp ASC');
  }
}
