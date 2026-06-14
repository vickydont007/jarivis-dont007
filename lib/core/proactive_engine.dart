import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ProactiveEngine {
  static Database? _database;
  static const _dbName = 'nextron_proactive.db';
  static Timer? _heartbeatTimer;
  static Timer? _checkinTimer;

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
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            repeat_type TEXT DEFAULT 'once',
            repeat_interval INTEGER,
            channel TEXT,
            is_active INTEGER DEFAULT 1,
            last_triggered TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE scheduled_tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            task_type TEXT NOT NULL,
            task_config TEXT NOT NULL,
            schedule TEXT NOT NULL,
            is_active INTEGER DEFAULT 1,
            last_run TEXT,
            next_run TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE check_ins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            check_in_type TEXT NOT NULL,
            questions TEXT NOT NULL,
            schedule TEXT NOT NULL,
            channel TEXT,
            is_active INTEGER DEFAULT 1,
            last_check_in TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE insights (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            insight_type TEXT NOT NULL,
            insight_text TEXT NOT NULL,
            relevance REAL DEFAULT 0.5,
            is_used INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Add a reminder
  Future<void> addReminder({
    required String title,
    required String message,
    required DateTime scheduledTime,
    String repeatType = 'once',
    int? repeatInterval,
    String? channel,
  }) async {
    final db = await database;
    await db.insert('reminders', {
      'title': title,
      'message': message,
      'scheduled_time': scheduledTime.toIso8601String(),
      'repeat_type': repeatType,
      'repeat_interval': repeatInterval,
      'channel': channel,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get active reminders
  Future<List<Map<String, dynamic>>> getActiveReminders() async {
    final db = await database;
    return await db.query(
      'reminders',
      where: 'is_active = 1',
      orderBy: 'scheduled_time ASC',
    );
  }

  // Check and trigger due reminders
  Future<List<Map<String, dynamic>>> checkDueReminders() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final dueReminders = await db.query(
      'reminders',
      where: 'is_active = 1 AND scheduled_time <= ?',
      whereArgs: [now],
    );

    for (final reminder in dueReminders) {
      await _triggerReminder(reminder);
    }

    return dueReminders;
  }

  Future<void> _triggerReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    final repeatType = reminder['repeat_type'] as String;

    if (repeatType == 'once') {
      await db.update(
        'reminders',
        {'is_active': 0, 'last_triggered': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [reminder['id']],
      );
    } else {
      final nextTime = _calculateNextTime(
        DateTime.parse(reminder['scheduled_time'] as String),
        repeatType,
        reminder['repeat_interval'] as int?,
      );
      await db.update(
        'reminders',
        {
          'scheduled_time': nextTime.toIso8601String(),
          'last_triggered': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [reminder['id']],
      );
    }
  }

  DateTime _calculateNextTime(DateTime current, String repeatType, int? interval) {
    switch (repeatType) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day, current.hour, current.minute);
      case 'hourly':
        return current.add(Duration(hours: interval ?? 1));
      case 'interval':
        return current.add(Duration(minutes: interval ?? 30));
      default:
        return current.add(const Duration(days: 1));
    }
  }

  // Add a scheduled task
  Future<void> addScheduledTask({
    required String name,
    required String taskType,
    required Map<String, dynamic> taskConfig,
    required String schedule,
  }) async {
    final db = await database;
    final nextRun = _parseSchedule(schedule);
    await db.insert('scheduled_tasks', {
      'name': name,
      'task_type': taskType,
      'task_config': jsonEncode(taskConfig),
      'schedule': schedule,
      'is_active': 1,
      'next_run': nextRun.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get active scheduled tasks
  Future<List<Map<String, dynamic>>> getActiveTasks() async {
    final db = await database;
    return await db.query(
      'scheduled_tasks',
      where: 'is_active = 1',
      orderBy: 'next_run ASC',
    );
  }

  // Check and run due tasks
  Future<List<Map<String, dynamic>>> checkDueTasks() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final dueTasks = await db.query(
      'scheduled_tasks',
      where: 'is_active = 1 AND next_run <= ?',
      whereArgs: [now],
    );

    for (final task in dueTasks) {
      await _runTask(task);
    }

    return dueTasks;
  }

  Future<void> _runTask(Map<String, dynamic> task) async {
    final db = await database;
    final schedule = task['schedule'] as String;
    final nextRun = _calculateNextRun(schedule);

    await db.update(
      'scheduled_tasks',
      {
        'last_run': DateTime.now().toIso8601String(),
        'next_run': nextRun.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [task['id']],
    );
  }

  DateTime _parseSchedule(String schedule) {
    // Simple schedule parsing: "daily:09:00", "hourly", "every:30m"
    final parts = schedule.split(':');
    if (parts.length == 2 && parts[0] == 'daily') {
      final timeParts = parts[1].split('-');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, hour, minute);
      if (next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }
      return next;
    } else if (parts[0] == 'hourly') {
      return DateTime.now().add(const Duration(hours: 1));
    } else if (parts[0] == 'every') {
      final duration = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      final unit = parts[1].replaceAll(RegExp(r'[0-9]'), '');
      if (unit == 'm' || unit == 'min') {
        return DateTime.now().add(Duration(minutes: duration));
      } else if (unit == 'h' || unit == 'hour') {
        return DateTime.now().add(Duration(hours: duration));
      }
    }
    return DateTime.now().add(const Duration(hours: 1));
  }

  DateTime _calculateNextRun(String schedule) {
    return _parseSchedule(schedule);
  }

  // Add a check-in
  Future<void> addCheckIn({
    required String checkInType,
    required List<String> questions,
    required String schedule,
    String? channel,
  }) async {
    final db = await database;
    await db.insert('check_ins', {
      'check_in_type': checkInType,
      'questions': jsonEncode(questions),
      'schedule': schedule,
      'channel': channel,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get active check-ins
  Future<List<Map<String, dynamic>>> getActiveCheckIns() async {
    final db = await database;
    return await db.query(
      'check_ins',
      where: 'is_active = 1',
    );
  }

  // Add an insight
  Future<void> addInsight({
    required String insightType,
    required String insightText,
    double relevance = 0.5,
  }) async {
    final db = await database;
    await db.insert('insights', {
      'insight_type': insightType,
      'insight_text': insightText,
      'relevance': relevance,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get unused insights
  Future<List<Map<String, dynamic>>> getUnusedInsights({int limit = 5}) async {
    final db = await database;
    return await db.query(
      'insights',
      where: 'is_used = 0',
      orderBy: 'relevance DESC',
      limit: limit,
    );
  }

  // Mark insight as used
  Future<void> markInsightUsed(int id) async {
    final db = await database;
    await db.update(
      'insights',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Start proactive engine
  void startEngine() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      checkDueReminders();
      checkDueTasks();
    });
  }

  // Stop proactive engine
  void stopEngine() {
    _heartbeatTimer?.cancel();
    _checkinTimer?.cancel();
  }

  // Get stats
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final activeReminders = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reminders WHERE is_active = 1'),
    );
    final activeTasks = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM scheduled_tasks WHERE is_active = 1'),
    );
    final activeCheckIns = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM check_ins WHERE is_active = 1'),
    );

    return {
      'active_reminders': activeReminders ?? 0,
      'active_tasks': activeTasks ?? 0,
      'active_check_ins': activeCheckIns ?? 0,
    };
  }

  Future<void> close() async {
    stopEngine();
    final db = await database;
    await db.close();
    _database = null;
  }
}
