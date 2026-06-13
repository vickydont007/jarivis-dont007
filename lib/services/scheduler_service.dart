import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

enum ScheduleType {
  once,
  daily,
  weekly,
  monthly,
  custom,
}

enum ScheduleStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

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
      id: const Uuid().v4(),
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

  Map<String, dynamic> toMap() {
    return {
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
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
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
    );
  }

  Schedule copyWith({
    ScheduleStatus? status,
    DateTime? completedAt,
    int? currentRepeat,
  }) {
    return Schedule(
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
    );
  }
}

class SchedulerService {
  static Database? _database;
  final Map<String, Timer> _timers = {};
  final StreamController<Schedule> _scheduleController =
      StreamController<Schedule>.broadcast();

  Stream<Schedule> get scheduleStream => _scheduleController.stream;

  SchedulerService() {
    _startScheduler();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_scheduler.db');

    return await openDatabase(
      path,
      version: 1,
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
            current_repeat INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  void _startScheduler() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkDueSchedules();
    });
  }

  Future<void> _checkDueSchedules() async {
    final now = DateTime.now();
    final schedules = await getAllSchedules();

    for (final schedule in schedules) {
      if (schedule.status == ScheduleStatus.pending &&
          schedule.scheduledAt != null &&
          schedule.scheduledAt!.isBefore(now)) {
        await _executeSchedule(schedule);
      }
    }
  }

  Future<void> _executeSchedule(Schedule schedule) async {
    final runningSchedule = schedule.copyWith(status: ScheduleStatus.running);
    await _updateSchedule(runningSchedule);
    _scheduleController.add(runningSchedule);

    try {
      await _executeTask(schedule);
      final completedSchedule = schedule.copyWith(
        status: ScheduleStatus.completed,
        completedAt: DateTime.now(),
        currentRepeat: schedule.currentRepeat + 1,
      );
      await _updateSchedule(completedSchedule);
      _scheduleController.add(completedSchedule);

      if (completedSchedule.currentRepeat < completedSchedule.repeatCount) {
        await _scheduleNextRepeat(completedSchedule);
      }
    } catch (e) {
      final failedSchedule = schedule.copyWith(
        status: ScheduleStatus.failed,
        completedAt: DateTime.now(),
      );
      await _updateSchedule(failedSchedule);
      _scheduleController.add(failedSchedule);
    }
  }

  Future<void> _executeTask(Schedule schedule) async {
    final action = schedule.payload['action'] as String?;
    final params = schedule.payload['params'] as Map<String, dynamic>?;

    switch (action) {
      case 'notification':
        break;
      case 'system':
        final command = params?['command'] as String?;
        if (command != null) {
          // System commands handled elsewhere
        }
        break;
      case 'ai':
        final prompt = params?['prompt'] as String?;
        if (prompt != null) {
          // AI task handled elsewhere
        }
        break;
      case 'file':
        final operation = params?['operation'] as String?;
        final path = params?['path'] as String?;
        if (operation != null && path != null) {
          // File operations handled elsewhere
        }
        break;
      default:
        break;
    }
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
        break;
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

  Future<void> _updateSchedule(Schedule schedule) async {
    final db = await database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Schedule createFromNaturalLanguage(String input) {
    final lowerInput = input.toLowerCase();
    ScheduleType type = ScheduleType.once;
    DateTime? scheduledAt;

    if (lowerInput.contains('daily') || lowerInput.contains('every day')) {
      type = ScheduleType.daily;
      scheduledAt = DateTime.now().add(const Duration(hours: 1));
    } else if (lowerInput.contains('weekly') || lowerInput.contains('every week')) {
      type = ScheduleType.weekly;
      scheduledAt = DateTime.now().add(const Duration(days: 1));
    } else if (lowerInput.contains('monthly') || lowerInput.contains('every month')) {
      type = ScheduleType.monthly;
      scheduledAt = DateTime.now().add(const Duration(days: 30));
    } else {
      final timeMatch = RegExp(r'at (\d{1,2}):?(\d{0,2})').firstMatch(lowerInput);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2) ?? '0');
        scheduledAt = DateTime.now();
        scheduledAt = scheduledAt.add(Duration(
          hours: hour - scheduledAt.hour,
          minutes: minute - scheduledAt.minute,
        ));
      }
    }

    return Schedule.create(
      name: 'Scheduled Task',
      description: input,
      type: type,
      scheduledAt: scheduledAt,
    );
  }

  Future<void> addSchedule(Schedule schedule) async {
    final db = await database;
    await db.insert('schedules', schedule.toMap());
    _scheduleController.add(schedule);

    if (schedule.scheduledAt != null) {
      final duration = schedule.scheduledAt!.difference(DateTime.now());
      if (duration.isNegative) return;

      _timers[schedule.id] = Timer(duration, () {
        _executeSchedule(schedule);
      });
    }
  }

  Future<void> cancelSchedule(String scheduleId) async {
    _timers[scheduleId]?.cancel();
    _timers.remove(scheduleId);

    final db = await database;
    final results = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    if (results.isNotEmpty) {
      final schedule = Schedule.fromMap(results.first);
      final cancelledSchedule = schedule.copyWith(status: ScheduleStatus.cancelled);
      await _updateSchedule(cancelledSchedule);
      _scheduleController.add(cancelledSchedule);
    }
  }

  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final results = await db.query('schedules', orderBy: 'created_at DESC');
    return results.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> getPendingSchedules() async {
    final db = await database;
    final results = await db.query(
      'schedules',
      where: 'status = ?',
      whereArgs: [ScheduleStatus.pending.name],
      orderBy: 'scheduled_at ASC',
    );
    return results.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> getCompletedSchedules() async {
    final db = await database;
    final results = await db.query(
      'schedules',
      where: 'status = ?',
      whereArgs: [ScheduleStatus.completed.name],
      orderBy: 'completed_at DESC',
    );
    return results.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    _timers[scheduleId]?.cancel();
    _timers.remove(scheduleId);

    final db = await database;
    await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _scheduleController.close();
  }
}
