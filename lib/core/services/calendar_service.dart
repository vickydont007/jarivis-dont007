import 'dart:async';
import 'package:uuid/uuid.dart';
import '../calendar_event.dart';
import 'local_calendar_provider.dart';

class CalendarService {
  final LocalCalendarProvider _localProvider;
  final _uuid = const Uuid();

  CalendarService({LocalCalendarProvider? localProvider})
      : _localProvider = localProvider ?? LocalCalendarProvider();

  void setUserId(String userId) {
    _localProvider.setUserId(userId);
  }

  Stream<List<CalendarEvent>> get eventsStream => _localProvider.eventsStream;

  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String description = '',
    String location = '',
    bool isAllDay = false,
    EventCategory category = EventCategory.other,
    EventRecurrence recurrence = EventRecurrence.none,
    int reminderMinutes = 15,
    String source = 'local',
  }) async {
    final event = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      startTime: startTime,
      endTime: endTime,
      description: description,
      location: location,
      isAllDay: isAllDay,
      category: category,
      recurrence: recurrence,
      reminderMinutes: reminderMinutes,
      source: source,
    );
    await _localProvider.insertEvent(event);
    return event;
  }

  Future<CalendarEvent?> updateEvent(String eventId, {
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? location,
    bool? isAllDay,
    EventCategory? category,
    EventRecurrence? recurrence,
    int? reminderMinutes,
  }) async {
    final existing = await _localProvider.getEvent(eventId);
    if (existing == null) return null;
    final updated = existing.copyWith(
      title: title,
      startTime: startTime,
      endTime: endTime,
      description: description,
      location: location,
      isAllDay: isAllDay,
      category: category,
      recurrence: recurrence,
      reminderMinutes: reminderMinutes,
    );
    await _localProvider.updateEvent(updated);
    return updated;
  }

  Future<bool> deleteEvent(String eventId) async {
    final existing = await _localProvider.getEvent(eventId);
    if (existing == null) return false;
    await _localProvider.deleteEvent(eventId);
    return true;
  }

  Future<CalendarEvent?> getEvent(String eventId) async {
    return await _localProvider.getEvent(eventId);
  }

  Future<List<CalendarEvent>> getAllEvents() async {
    return await _localProvider.getAllEvents();
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    return await _localProvider.getEventsForDate(date);
  }

  Future<List<CalendarEvent>> getEventsInRange(DateTime start, DateTime end) async {
    return await _localProvider.getEventsInRange(start, end);
  }

  Future<List<CalendarEvent>> getUpcomingEvents({int limit = 10}) async {
    return await _localProvider.getUpcomingEvents(limit: limit);
  }

  Future<List<CalendarEvent>> searchEvents(String query) async {
    return await _localProvider.searchEvents(query);
  }

  Future<List<CalendarEvent>> getEventsByCategory(EventCategory category) async {
    return await _localProvider.getEventsByCategory(category);
  }

  Future<List<DateTime>> getFreeSlots(DateTime date, {int slotMinutes = 30}) async {
    return await _localProvider.getFreeSlots(date, slotMinutes: slotMinutes);
  }

  Future<bool> markCompleted(String eventId) async {
    final existing = await _localProvider.getEvent(eventId);
    if (existing == null) return false;
    await _localProvider.markCompleted(eventId);
    return true;
  }

  Future<List<CalendarEvent>> getTodayEvents() async {
    return await getEventsForDate(DateTime.now());
  }

  Future<List<CalendarEvent>> getTomorrowEvents() async {
    return await getEventsForDate(DateTime.now().add(const Duration(days: 1)));
  }

  Future<List<CalendarEvent>> getWeekEvents() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return await getEventsInRange(startOfWeek, endOfWeek);
  }

  Future<Map<String, dynamic>> getAgenda() async {
    final today = await getTodayEvents();
    final tomorrow = await getTomorrowEvents();
    final upcoming = await getUpcomingEvents(limit: 20);

    return {
      'today': today,
      'tomorrow': tomorrow,
      'upcoming': upcoming,
      'today_count': today.length,
      'tomorrow_count': tomorrow.length,
      'upcoming_count': upcoming.length,
    };
  }

  Future<Map<String, dynamic>> findFreeTime({
    required DateTime date,
    int durationMinutes = 60,
    int? preferredHour,
  }) async {
    final freeSlots = await _localProvider.getFreeSlots(date, slotMinutes: 15);
    if (freeSlots.isEmpty) {
      return {'free': false, 'message': 'No free slots available on ${date.month}/${date.day}'};
    }

    final suitable = <DateTime>[];
    for (final slot in freeSlots) {
      if (preferredHour != null && slot.hour != preferredHour) continue;
      final slotEnd = slot.add(Duration(minutes: durationMinutes));
      final stillFree = freeSlots.where((s) =>
          s.isAfter(slot) && s.isBefore(slotEnd)).length >= (durationMinutes ~/ 15) - 1;
      if (stillFree) suitable.add(slot);
    }

    if (suitable.isEmpty) {
      return {
        'free': true,
        'next_available': freeSlots.first,
        'message': 'Next free slot at ${freeSlots.first.hour}:${freeSlots.first.minute.toString().padLeft(2, '0')}',
      };
    }

    final best = preferredHour != null
        ? suitable.firstWhere((s) => s.hour >= preferredHour, orElse: () => suitable.first)
        : suitable.first;

    return {
      'free': true,
      'slot': best,
      'end': best.add(Duration(minutes: durationMinutes)),
      'message': 'Free at ${best.hour}:${best.minute.toString().padLeft(2, '0')} - ${best.add(Duration(minutes: durationMinutes)).hour}:${best.add(Duration(minutes: durationMinutes)).minute.toString().padLeft(2, '0')}',
    };
  }

  Future<String> generateScheduleSummary() async {
    final agenda = await getAgenda();
    final todayEvents = agenda['today'] as List<CalendarEvent>;
    final tomorrowEvents = agenda['tomorrow'] as List<CalendarEvent>;

    final buffer = StringBuffer();
    buffer.writeln('📅 Calendar Summary');
    buffer.writeln('');

    if (todayEvents.isEmpty) {
      buffer.writeln('Today: No events scheduled');
    } else {
      buffer.writeln('Today (${todayEvents.length} events):');
      for (final e in todayEvents) {
        final time = e.isAllDay ? 'All day' : '${e.startTimeStr} - ${e.endTimeStr}';
        buffer.writeln('  • ${e.title} ($time)');
      }
    }

    buffer.writeln('');

    if (tomorrowEvents.isEmpty) {
      buffer.writeln('Tomorrow: No events scheduled');
    } else {
      buffer.writeln('Tomorrow (${tomorrowEvents.length} events):');
      for (final e in tomorrowEvents) {
        final time = e.isAllDay ? 'All day' : '${e.startTimeStr} - ${e.endTimeStr}';
        buffer.writeln('  • ${e.title} ($time)');
      }
    }

    return buffer.toString();
  }

  void dispose() {
    _localProvider.dispose();
  }
}
