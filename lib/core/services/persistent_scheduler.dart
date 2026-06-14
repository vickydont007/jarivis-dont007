import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

enum ScheduleType { once, daily, weekly, monthly, custom }

enum ScheduleStatus { pending, running, completed, failed, cancelled }

class Schedule {
  final String id;
  final String name;
  final String description;
  final ScheduleType type;
  final ScheduleStatus status;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final String? cronExpression;
  final Map<String, dynamic> payload;
  final int repeatCount;
  final int currentRepeat;
  final String? lastError;

  Schedule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.status = ScheduleStatus.pending,
    required this.createdAt,
    this.scheduledAt,
    this.completedAt,
    this.cronExpression,
    this.payload = const {},
    this.repeatCount = 1,
    this.currentRepeat = 0,
    this.lastError,
  });

  factory Schedule.create({
    required String name,
    required String description,
    required ScheduleType type,
    DateTime? scheduledAt,
    String? cronExpression,
    Map<String, dynamic> payload = const {},
    int repeatCount = 1,
  }) {
    return Schedule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      type: type,
      scheduledAt: scheduledAt,
      cronExpression: cronExpression,
      payload: payload,
      repeatCount: repeatCount,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'scheduled_at': scheduledAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'cron_expression': cronExpression,
    'payload': jsonEncode(payload),
    'repeat_count': repeatCount,
    'current_repeat': currentRepeat,
    'last_error': lastError,
  };

  factory Schedule.fromMap(Map<String, dynamic> map) => Schedule(
    id: map['id'],
    name: map['name'],
    description: map['description'],
    type: ScheduleType.values.firstWhere((t) => t.name == map['type']),
    status: ScheduleStatus.values.firstWhere((s) => s.name == map['status']),
    createdAt: DateTime.parse(map['created_at']),
    scheduledAt: map['scheduled_at'] != null ? DateTime.parse(map['scheduled_at']) : null,
    completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    cronExpression: map['cron_expression'],
    payload: jsonDecode(map['payload'] ?? '{}'),
    repeatCount: map['repeat_count'] ?? 1,
    currentRepeat: map['current_repeat'] ?? 0,
    lastError: map['last_error'],
  );

  Schedule copyWith({
    ScheduleStatus? status,
    DateTime? completedAt,
    int? currentRepeat,
    String? lastError,
  }) => Schedule(
    id: id,
    name: name,
    description: description,
    type: type,
    status: status ?? this.status,
    createdAt: createdAt,
    scheduledAt: scheduledAt,
    completedAt: completedAt ?? this.completedAt,
    cronExpression: cronExpression,
    payload: payload,
    repeatCount: repeatCount,
    currentRepeat: currentRepeat ?? this.currentRepeat,
    lastError: lastError ?? this.lastError,
  );
}

class ExecutionRecord {
  final String id;
  final String scheduleId;
  final String scheduleName;
  final String status;
  final DateTime executedAt;
  final DateTime? completedAt;
  final String? result;
  final String? error;
  final int? durationMs;

  ExecutionRecord({
    required this.id,
    required this.scheduleId,
    required this.scheduleName,
    required this.status,
    required this.executedAt,
    this.completedAt,
    this.result,
    this.error,
    this.durationMs,
  });

  factory ExecutionRecord.create({
    required String scheduleId,
    required String scheduleName,
  }) => ExecutionRecord(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    scheduleId: scheduleId,
    scheduleName: scheduleName,
    status: 'running',
    executedAt: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'schedule_id': scheduleId,
    'schedule_name': scheduleName,
    'status': status,
    'executed_at': executedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'result': result,
    'error': error,
    'duration_ms': durationMs,
  };

  factory ExecutionRecord.fromMap(Map<String, dynamic> map) => ExecutionRecord(
    id: map['id'],
    scheduleId: map['schedule_id'],
    scheduleName: map['schedule_name'],
    status: map['status'],
    executedAt: DateTime.parse(map['executed_at']),
    completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    result: map['result'],
    error: map['error'],
    durationMs: map['duration_ms'],
  );
}

typedef TaskExecutor = Future<String> Function(Map<String, dynamic> payload);

class PersistentScheduler {
  static Database? _database;
  static const _dbName = 'nextron_scheduler.db';
  final Map<String, Timer> _timers = {};
  final Map<String, TaskExecutor> _executors = {};
  final StreamController<Schedule> _scheduleController =
      StreamController<Schedule>.broadcast();
  final StreamController<ExecutionRecord> _executionController =
      StreamController<ExecutionRecord>.broadcast();

  Stream<Schedule> get scheduleStream => _scheduleController.stream;
  Stream<ExecutionRecord> get executionStream => _executionController.stream;

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
          CREATE TABLE schedules(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            scheduled_at TEXT,
            completed_at TEXT,
            cron_expression TEXT,
            payload TEXT DEFAULT '{}',
            repeat_count INTEGER DEFAULT 1,
            current_repeat INTEGER DEFAULT 0,
            last_error TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE execution_history(
            id TEXT PRIMARY KEY,
            schedule_id TEXT NOT NULL,
            schedule_name TEXT NOT NULL,
            status TEXT NOT NULL,
            executed_at TEXT NOT NULL,
            completed_at TEXT,
            result TEXT,
            error TEXT,
            duration_ms INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS execution_history(
              id TEXT PRIMARY KEY,
              schedule_id TEXT NOT NULL,
              schedule_name TEXT NOT NULL,
              status TEXT NOT NULL,
              executed_at TEXT NOT NULL,
              completed_at TEXT,
              result TEXT,
              error TEXT,
              duration_ms INTEGER
            )
          ''');
        }
      },
    );
  }

  Future<void> initialize() async {
    await database;
    await _restoreSchedules();
  }

  Future<void> _restoreSchedules() async {
    final pending = await _getSchedulesByStatus(ScheduleStatus.pending);
    final running = await _getSchedulesByStatus(ScheduleStatus.running);

    for (final schedule in [...pending, ...running]) {
      if (schedule.scheduledAt != null) {
        if (schedule.scheduledAt!.isBefore(DateTime.now())) {
          _executeSchedule(schedule);
        } else {
          _startTimer(schedule);
        }
      }
    }
  }

  void registerExecutor(String actionType, TaskExecutor executor) {
    _executors[actionType] = executor;
  }

  void _startTimer(Schedule schedule) {
    if (schedule.scheduledAt == null) return;
    final duration = schedule.scheduledAt!.difference(DateTime.now());
    if (duration.isNegative) {
      _executeSchedule(schedule);
      return;
    }
    _timers[schedule.id] = Timer(duration, () {
      _executeSchedule(schedule);
    });
  }

  Future<void> _executeSchedule(Schedule schedule) async {
    final runningSchedule = schedule.copyWith(status: ScheduleStatus.running);
    await _updateSchedule(runningSchedule);
    _scheduleController.add(runningSchedule);

    final record = ExecutionRecord.create(
      scheduleId: schedule.id,
      scheduleName: schedule.name,
    );

    try {
      final executor = _executors[schedule.payload['action'] as String?];
      String result;
      if (executor != null) {
        result = await executor(schedule.payload);
      } else {
        result = await _defaultExecute(schedule);
      }

      final completedSchedule = schedule.copyWith(
        status: ScheduleStatus.completed,
        completedAt: DateTime.now(),
        currentRepeat: schedule.currentRepeat + 1,
      );
      await _updateSchedule(completedSchedule);
      _scheduleController.add(completedSchedule);

      final completedRecord = ExecutionRecord(
        id: record.id,
        scheduleId: record.scheduleId,
        scheduleName: record.scheduleName,
        status: 'completed',
        executedAt: record.executedAt,
        completedAt: DateTime.now(),
        result: result,
        durationMs: DateTime.now().difference(record.executedAt).inMilliseconds,
      );
      await _logExecution(completedRecord);
      _executionController.add(completedRecord);

      if (completedSchedule.currentRepeat < completedSchedule.repeatCount &&
          completedSchedule.type != ScheduleType.once) {
        await _scheduleNextRepeat(completedSchedule);
      }
    } catch (e) {
      final failedSchedule = schedule.copyWith(
        status: ScheduleStatus.failed,
        completedAt: DateTime.now(),
        lastError: e.toString(),
      );
      await _updateSchedule(failedSchedule);
      _scheduleController.add(failedSchedule);

      final failedRecord = ExecutionRecord(
        id: record.id,
        scheduleId: record.scheduleId,
        scheduleName: record.scheduleName,
        status: 'failed',
        executedAt: record.executedAt,
        completedAt: DateTime.now(),
        error: e.toString(),
        durationMs: DateTime.now().difference(record.executedAt).inMilliseconds,
      );
      await _logExecution(failedRecord);
      _executionController.add(failedRecord);
    }
  }

  Future<String> _defaultExecute(Schedule schedule) async {
    final action = schedule.payload['action'] as String?;
    final params = schedule.payload['params'] as Map<String, dynamic>?;
    return 'Executed: $action (${params ?? {}})';
  }

  Future<void> _scheduleNextRepeat(Schedule schedule) async {
    DateTime? nextScheduledAt;
    switch (schedule.type) {
      case ScheduleType.daily:
        nextScheduledAt = schedule.scheduledAt?.add(const Duration(days: 1));
        break;
      case ScheduleType.weekly:
        nextScheduledAt = schedule.scheduledAt?.add(const Duration(days: 7));
        break;
      case ScheduleType.monthly:
        nextScheduledAt = schedule.scheduledAt?.add(const Duration(days: 30));
        break;
      default:
        return;
    }

    if (nextScheduledAt != null) {
      final nextSchedule = Schedule.create(
        name: schedule.name,
        description: schedule.description,
        type: schedule.type,
        scheduledAt: nextScheduledAt,
        cronExpression: schedule.cronExpression,
        payload: schedule.payload,
        repeatCount: schedule.repeatCount,
      );
      await addSchedule(nextSchedule);
    }
  }

  Future<void> addSchedule(Schedule schedule) async {
    final db = await database;
    await db.insert('schedules', schedule.toMap());
    _scheduleController.add(schedule);
    _startTimer(schedule);
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await _updateSchedule(schedule);
    _scheduleController.add(schedule);
  }

  Future<void> _updateSchedule(Schedule schedule) async {
    final db = await database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<void> cancelSchedule(String scheduleId) async {
    _timers[scheduleId]?.cancel();
    _timers.remove(scheduleId);
    final db = await database;
    final results = await db.query('schedules', where: 'id = ?', whereArgs: [scheduleId]);
    if (results.isNotEmpty) {
      final schedule = Schedule.fromMap(results.first);
      final cancelled = schedule.copyWith(status: ScheduleStatus.cancelled);
      await _updateSchedule(cancelled);
      _scheduleController.add(cancelled);
    }
  }

  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final results = await db.query('schedules', orderBy: 'created_at DESC');
    return results.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> getPendingSchedules() async {
    return _getSchedulesByStatus(ScheduleStatus.pending);
  }

  Future<List<Schedule>> getActiveSchedules() async {
    final db = await database;
    final results = await db.query(
      'schedules',
      where: 'status IN (?, ?)',
      whereArgs: [ScheduleStatus.pending.name, ScheduleStatus.running.name],
      orderBy: 'scheduled_at ASC',
    );
    return results.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> _getSchedulesByStatus(ScheduleStatus status) async {
    final db = await database;
    final results = await db.query(
      'schedules',
      where: 'status = ?',
      whereArgs: [status.name],
    );
    return results.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<void> _logExecution(ExecutionRecord record) async {
    final db = await database;
    await db.insert('execution_history', record.toMap());
  }

  Future<List<ExecutionRecord>> getExecutionHistory({String? scheduleId, int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'execution_history',
      where: scheduleId != null ? 'schedule_id = ?' : null,
      whereArgs: scheduleId != null ? [scheduleId] : null,
      orderBy: 'executed_at DESC',
      limit: limit,
    );
    return results.map((map) => ExecutionRecord.fromMap(map)).toList();
  }

  Future<int> getExecutionCount(String scheduleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM execution_history WHERE schedule_id = ?',
      [scheduleId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteSchedule(String scheduleId) async {
    _timers[scheduleId]?.cancel();
    _timers.remove(scheduleId);
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
  }

  Future<void> clearExecutionHistory() async {
    final db = await database;
    await db.delete('execution_history');
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _scheduleController.close();
    _executionController.close();
  }
}
