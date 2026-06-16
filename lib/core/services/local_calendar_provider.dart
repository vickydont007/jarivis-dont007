import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../calendar_event.dart';

class LocalCalendarProvider {
  static Database? _database;
  static const _dbName = 'nextron_calendar.db';

  final StreamController<List<CalendarEvent>> _eventsController =
      StreamController<List<CalendarEvent>>.broadcast();

  Stream<List<CalendarEvent>> get eventsStream => _eventsController.stream;

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
          CREATE TABLE calendar_events(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            description TEXT DEFAULT '',
            location TEXT DEFAULT '',
            is_all_day INTEGER DEFAULT 0,
            category TEXT DEFAULT 'other',
            recurrence TEXT DEFAULT 'none',
            reminder_minutes INTEGER DEFAULT 15,
            is_completed INTEGER DEFAULT 0,
            external_id TEXT,
            source TEXT DEFAULT 'local',
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE calendar_reminders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id TEXT NOT NULL,
            remind_at TEXT NOT NULL,
            message TEXT NOT NULL,
            is_fired INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_events_start ON calendar_events(start_time)');
        await db.execute('CREATE INDEX idx_events_category ON calendar_events(category)');
        await db.execute('CREATE INDEX idx_reminders_event ON calendar_reminders(event_id)');
        await db.execute('CREATE INDEX idx_reminders_time ON calendar_reminders(remind_at)');
      },
    );
  }

  Future<void> insertEvent(CalendarEvent event) async {
    final db = await database;
    await db.insert('calendar_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _syncReminders(event);
    await _notifyListeners();
  }

  Future<void> insertEvents(List<CalendarEvent> events) async {
    final db = await database;
    final batch = db.batch();
    for (final event in events) {
      batch.insert('calendar_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await _syncReminders(event);
    }
    await batch.commit(noResult: true);
    await _notifyListeners();
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final db = await database;
    await db.update('calendar_events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
    await _syncReminders(event);
    await _notifyListeners();
  }

  Future<void> deleteEvent(String eventId) async {
    final db = await database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [eventId]);
    await db.delete('calendar_reminders', where: 'event_id = ?', whereArgs: [eventId]);
    await _notifyListeners();
  }

  Future<CalendarEvent?> getEvent(String eventId) async {
    final db = await database;
    final results = await db.query('calendar_events', where: 'id = ?', whereArgs: [eventId], limit: 1);
    if (results.isEmpty) return null;
    return CalendarEvent.fromMap(results.first);
  }

  Future<List<CalendarEvent>> getAllEvents() async {
    final db = await database;
    final results = await db.query('calendar_events', orderBy: 'start_time ASC');
    return results.map((r) => CalendarEvent.fromMap(r)).toList();
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final results = await db.query(
      'calendar_events',
      where: 'start_time >= ? AND start_time < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return results.map((r) => CalendarEvent.fromMap(r)).toList();
  }

  Future<List<CalendarEvent>> getEventsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final results = await db.query(
      'calendar_events',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return results.map((r) => CalendarEvent.fromMap(r)).toList();
  }

  Future<List<CalendarEvent>> getUpcomingEvents({int limit = 10}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final results = await db.query(
      'calendar_events',
      where: 'start_time >= ? AND is_completed = 0',
      whereArgs: [now],
      orderBy: 'start_time ASC',
      limit: limit,
    );
    return results.map((r) => CalendarEvent.fromMap(r)).toList();
  }

  Future<List<CalendarEvent>> searchEvents(String query) async {
    final db = await database;
    final results = await db.query(
      'calendar_events',
      where: 'title LIKE ? OR description LIKE ? OR location LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'start_time ASC',
    );
    return results.map((r) => CalendarEvent.fromMap(r)).toList();
  }

  Future<List<CalendarEvent>> getEventsByCategory(EventCategory category) async {
    final db = await database;
    final results = await db.query(
      'calendar_events',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'start_time ASC',
    );
    return results.map((r) => CalendarEvent.fromMap(r)).toList();
  }

  Future<List<DateTime>> getFreeSlots(DateTime date, {int slotMinutes = 30}) async {
    final events = await getEventsForDate(date);
    final startOfDay = DateTime(date.year, date.month, date.day, 8, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 22, 0);
    final freeSlots = <DateTime>[];
    var current = startOfDay;

    while (current.isBefore(endOfDay)) {
      final slotEnd = current.add(Duration(minutes: slotMinutes));
      final isBusy = events.any((e) {
        final eventStart = e.startTime;
        final eventEnd = e.endTime;
        return current.isBefore(eventEnd) && slotEnd.isAfter(eventStart);
      });
      if (!isBusy) freeSlots.add(current);
      current = slotEnd;
    }
    return freeSlots;
  }

  Future<void> markCompleted(String eventId) async {
    final db = await database;
    await db.update('calendar_events', {'is_completed': 1}, where: 'id = ?', whereArgs: [eventId]);
    await _notifyListeners();
  }

  Future<void> _syncReminders(CalendarEvent event) async {
    final db = await database;
    await db.delete('calendar_reminders', where: 'event_id = ?', whereArgs: [event.id]);
    if (event.reminderMinutes > 0 && !event.isCompleted) {
      final remindAt = event.startTime.subtract(Duration(minutes: event.reminderMinutes));
      if (remindAt.isAfter(DateTime.now())) {
        await db.insert('calendar_reminders', {
          'event_id': event.id,
          'remind_at': remindAt.toIso8601String(),
          'message': '${event.title} starts in ${event.reminderMinutes} minutes',
          'is_fired': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPendingReminders() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'calendar_reminders',
      where: 'remind_at <= ? AND is_fired = 0',
      whereArgs: [now],
    );
  }

  Future<void> markReminderFired(int reminderId) async {
    final db = await database;
    await db.update('calendar_reminders', {'is_fired': 1}, where: 'id = ?', whereArgs: [reminderId]);
  }

  Future<void> _notifyListeners() async {
    final events = await getAllEvents();
    _eventsController.add(events);
  }

  void dispose() {
    _eventsController.close();
  }
}
