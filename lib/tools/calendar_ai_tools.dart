import 'dart:async';
import 'package:intl/intl.dart';
import '../core/calendar_event.dart';
import '../core/services/calendar_service.dart';
import 'tool.dart';

class CalendarCreateEventTool extends Tool {
  final CalendarService _calendarService;
  CalendarCreateEventTool(this._calendarService)
      : super(
          name: 'calendar_create_event',
          description: 'Create a new calendar event. Date format: YYYY-MM-DD. Time format: HH:MM (24h).',
          parameters: [
            const ToolParameter(name: 'title', description: 'Event title', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'date', description: 'Event date YYYY-MM-DD', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'time', description: 'Start time HH:MM (24h)', type: ToolParameterType.string),
            const ToolParameter(name: 'end_time', description: 'End time HH:MM (24h)', type: ToolParameterType.string),
            const ToolParameter(name: 'description', description: 'Event description', type: ToolParameterType.string),
            const ToolParameter(name: 'location', description: 'Event location', type: ToolParameterType.string),
            const ToolParameter(name: 'reminder_minutes', description: 'Reminder before event (minutes)', type: ToolParameterType.integer),
            const ToolParameter(name: 'category', description: 'Event category', type: ToolParameterType.string, enumValues: ['meeting', 'personal', 'work', 'health', 'social', 'other']),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final title = params['title'] as String;
      final dateStr = params['date'] as String;
      final timeStr = (params['time'] as String?) ?? '10:00';
      final endTimeStr = params['end_time'] as String?;
      final description = (params['description'] as String?) ?? '';
      final location = (params['location'] as String?) ?? '';
      final reminderMinutes = (params['reminder_minutes'] as int?) ?? 15;
      final categoryStr = (params['category'] as String?) ?? 'other';

      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      final startTime = DateTime(date.year, date.month, date.day, hour, minute);

      DateTime endTime;
      if (endTimeStr != null) {
        final endParts = endTimeStr.split(':');
        final endHour = int.parse(endParts[0]);
        final endMinute = endParts.length > 1 ? int.parse(endParts[1]) : 0;
        endTime = DateTime(date.year, date.month, date.day, endHour, endMinute);
      } else {
        endTime = startTime.add(const Duration(hours: 1));
      }

      final category = EventCategory.values.firstWhere(
        (c) => c.name == categoryStr,
        orElse: () => EventCategory.other,
      );

      final event = await _calendarService.createEvent(
        title: title,
        startTime: startTime,
        endTime: endTime,
        description: description,
        location: location,
        category: category,
        reminderMinutes: reminderMinutes,
        source: 'ai',
      );

      return ToolResult.success('Created event "${event.title}" on ${event.dateStr} at ${event.startTimeStr}');
    } catch (e) {
      return ToolResult.error('Failed to create event: $e');
    }
  }
}

class CalendarUpdateEventTool extends Tool {
  final CalendarService _calendarService;
  CalendarUpdateEventTool(this._calendarService)
      : super(
          name: 'calendar_update_event',
          description: 'Update an existing calendar event by its ID or title',
          parameters: [
            const ToolParameter(name: 'event_id', description: 'Event ID', type: ToolParameterType.string),
            const ToolParameter(name: 'title_match', description: 'Event title to search for (if event_id not known)', type: ToolParameterType.string),
            const ToolParameter(name: 'new_title', description: 'New title', type: ToolParameterType.string),
            const ToolParameter(name: 'new_date', description: 'New date YYYY-MM-DD', type: ToolParameterType.string),
            const ToolParameter(name: 'new_time', description: 'New start time HH:MM', type: ToolParameterType.string),
            const ToolParameter(name: 'new_end_time', description: 'New end time HH:MM', type: ToolParameterType.string),
            const ToolParameter(name: 'new_location', description: 'New location', type: ToolParameterType.string),
            const ToolParameter(name: 'new_description', description: 'New description', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      String? eventId = params['event_id'] as String?;
      final titleMatch = params['title_match'] as String?;

      if (eventId == null && titleMatch == null) {
        return ToolResult.error('Provide event_id or title_match to identify the event');
      }

      if (eventId == null) {
        final events = await _calendarService.searchEvents(titleMatch!);
        if (events.isEmpty) return ToolResult.error('No event found matching "$titleMatch"');
        eventId = events.first.id;
      }

      final updates = <String, dynamic>{};
      if (params['new_title'] != null) updates['title'] = params['new_title'];
      if (params['new_location'] != null) updates['location'] = params['new_location'];
      if (params['new_description'] != null) updates['description'] = params['new_description'];

      if (params['new_date'] != null || params['new_time'] != null) {
        final existing = await _calendarService.getEvent(eventId);
        if (existing == null) return ToolResult.error('Event not found');
        final dateStr = (params['new_date'] as String?) ?? existing.dateStr;
        final timeStr = (params['new_time'] as String?) ?? existing.startTimeStr;
        final endTimeStr = params['new_end_time'] as String?;

        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
        final timeParts = timeStr.split(':');
        final startTime = DateTime(date.year, date.month, date.day, int.parse(timeParts[0]), timeParts.length > 1 ? int.parse(timeParts[1]) : 0);
        updates['startTime'] = startTime;

        if (endTimeStr != null) {
          final endParts = endTimeStr.split(':');
          updates['endTime'] = DateTime(date.year, date.month, date.day, int.parse(endParts[0]), endParts.length > 1 ? int.parse(endParts[1]) : 0);
        } else {
          updates['endTime'] = startTime.add(Duration(milliseconds: existing.duration.inMilliseconds));
        }
      }

      if (updates.isEmpty) return ToolResult.error('No updates specified');

      final updated = await _calendarService.updateEvent(eventId, title: updates['title'], startTime: updates['startTime'], endTime: updates['endTime'], description: updates['new_description'], location: updates['location']);
      if (updated == null) return ToolResult.error('Event not found or update failed');
      return ToolResult.success('Updated event "${updated.title}" on ${updated.dateStr}');
    } catch (e) {
      return ToolResult.error('Failed to update event: $e');
    }
  }
}

class CalendarDeleteEventTool extends Tool {
  final CalendarService _calendarService;
  CalendarDeleteEventTool(this._calendarService)
      : super(
          name: 'calendar_delete_event',
          description: 'Delete a calendar event by ID or title',
          parameters: [
            const ToolParameter(name: 'event_id', description: 'Event ID', type: ToolParameterType.string),
            const ToolParameter(name: 'title_match', description: 'Event title to search and delete', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      String? eventId = params['event_id'] as String?;
      final titleMatch = params['title_match'] as String?;

      if (eventId == null && titleMatch == null) {
        return ToolResult.error('Provide event_id or title_match');
      }

      if (eventId == null) {
        final events = await _calendarService.searchEvents(titleMatch!);
        if (events.isEmpty) return ToolResult.error('No event found matching "$titleMatch"');
        final deleted = await _calendarService.deleteEvent(events.first.id);
        return deleted
            ? ToolResult.success('Deleted event "$titleMatch"')
            : ToolResult.error('Failed to delete event');
      }

      final deleted = await _calendarService.deleteEvent(eventId);
      return deleted
          ? ToolResult.success('Deleted event with ID $eventId')
          : ToolResult.error('Event not found');
    } catch (e) {
      return ToolResult.error('Failed to delete event: $e');
    }
  }
}

class CalendarListEventsTool extends Tool {
  final CalendarService _calendarService;
  CalendarListEventsTool(this._calendarService)
      : super(
          name: 'calendar_list_events',
          description: 'List calendar events for today, tomorrow, a specific date, or upcoming',
          parameters: [
            const ToolParameter(name: 'range', description: 'Time range', type: ToolParameterType.string, enumValues: ['today', 'tomorrow', 'week', 'upcoming']),
            const ToolParameter(name: 'date', description: 'Specific date YYYY-MM-DD', type: ToolParameterType.string),
            const ToolParameter(name: 'days', description: 'Number of days to look ahead (default: 7)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final range = (params['range'] as String?) ?? 'upcoming';
      final dateStr = params['date'] as String?;
      final days = (params['days'] as int?) ?? 7;

      List<CalendarEvent> events;
      String label;

      if (dateStr != null) {
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
        events = await _calendarService.getEventsForDate(date);
        label = 'Events on $dateStr';
      } else {
        switch (range) {
          case 'today':
            events = await _calendarService.getTodayEvents();
            label = 'Today\'s events';
            break;
          case 'tomorrow':
            events = await _calendarService.getTomorrowEvents();
            label = 'Tomorrow\'s events';
            break;
          case 'week':
            events = await _calendarService.getWeekEvents();
            label = 'This week\'s events';
            break;
          default:
            events = await _calendarService.getUpcomingEvents(limit: days * 3);
            label = 'Upcoming events ($days days)';
        }
      }

      if (events.isEmpty) {
        return ToolResult.success('No $label found');
      }

      final buffer = StringBuffer('$label (${events.length}):\n');
      for (final e in events) {
        final time = e.isAllDay ? 'All day' : '${e.startTimeStr} - ${e.endTimeStr}';
        final status = e.isCompleted ? ' ✓' : '';
        buffer.writeln('• ${e.title}$status - $time');
        if (e.location.isNotEmpty) buffer.writeln('  📍 ${e.location}');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to list events: $e');
    }
  }
}

class CalendarFindFreeTimeTool extends Tool {
  final CalendarService _calendarService;
  CalendarFindFreeTimeTool(this._calendarService)
      : super(
          name: 'calendar_find_free_time',
          description: 'Find free time slots on a given date',
          parameters: [
            const ToolParameter(name: 'date', description: 'Date to check YYYY-MM-DD', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'duration_minutes', description: 'Required free duration in minutes (default: 60)', type: ToolParameterType.integer),
            const ToolParameter(name: 'preferred_hour', description: 'Preferred start hour (0-23)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final dateStr = params['date'] as String;
      final duration = (params['duration_minutes'] as int?) ?? 60;
      final preferredHour = params['preferred_hour'] as int?;

      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      final result = await _calendarService.findFreeTime(
        date: date,
        durationMinutes: duration,
        preferredHour: preferredHour,
      );

      if (result['free'] == true) {
        final slot = result['slot'] as DateTime?;
        final end = result['end'] as DateTime?;
        if (slot != null && end != null) {
          return ToolResult.success('Free slot: ${slot.hour}:${slot.minute.toString().padLeft(2, '0')} - ${end.hour}:${end.minute.toString().padLeft(2, '0')}');
        }
        return ToolResult.success(result['message'] as String);
      }
      return ToolResult.success(result['message'] as String);
    } catch (e) {
      return ToolResult.error('Failed to find free time: $e');
    }
  }
}

class CalendarGetTodayTool extends Tool {
  final CalendarService _calendarService;
  CalendarGetTodayTool(this._calendarService)
      : super(
          name: 'calendar_get_today',
          description: 'Get today\'s agenda with all events',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final events = await _calendarService.getTodayEvents();
      if (events.isEmpty) {
        return ToolResult.success('No events scheduled for today');
      }

      final buffer = StringBuffer('📅 Today\'s Agenda (${events.length} events):\n');
      for (final e in events) {
        final time = e.isAllDay ? 'All day' : '${e.startTimeStr} - ${e.endTimeStr}';
        final status = e.isCompleted ? ' ✓' : '';
        buffer.writeln('• ${e.title}$status - $time');
        if (e.description.isNotEmpty) buffer.writeln('  ${e.description}');
        if (e.location.isNotEmpty) buffer.writeln('  📍 ${e.location}');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to get today\'s agenda: $e');
    }
  }
}

class CalendarGetWeekTool extends Tool {
  final CalendarService _calendarService;
  CalendarGetWeekTool(this._calendarService)
      : super(
          name: 'calendar_get_week',
          description: 'Get this week\'s calendar events',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final events = await _calendarService.getWeekEvents();
      if (events.isEmpty) {
        return ToolResult.success('No events this week');
      }

      final buffer = StringBuffer('📅 This Week (${events.length} events):\n');
      String? currentDay;
      for (final e in events) {
        final dayLabel = DateFormat('EEEE, MMM d').format(e.startTime);
        if (dayLabel != currentDay) {
          currentDay = dayLabel;
          buffer.writeln('\n$dayLabel:');
        }
        final time = e.isAllDay ? 'All day' : '${e.startTimeStr} - ${e.endTimeStr}';
        buffer.writeln('  • ${e.title} ($time)');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to get week events: $e');
    }
  }
}

class CalendarSearchEventsTool extends Tool {
  final CalendarService _calendarService;
  CalendarSearchEventsTool(this._calendarService)
      : super(
          name: 'calendar_search_events',
          description: 'Search calendar events by keyword in title, description, or location',
          parameters: [
            const ToolParameter(name: 'query', description: 'Search keyword', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final query = params['query'] as String;
      final events = await _calendarService.searchEvents(query);

      if (events.isEmpty) {
        return ToolResult.success('No events found matching "$query"');
      }

      final buffer = StringBuffer('🔍 Search results for "$query" (${events.length}):\n');
      for (final e in events) {
        final time = e.isAllDay ? 'All day' : '${e.dateStr} ${e.startTimeStr}';
        buffer.writeln('• ${e.title} - $time');
        if (e.description.isNotEmpty) buffer.writeln('  ${e.description}');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to search events: $e');
    }
  }
}

List<Tool> getAllCalendarAITools(CalendarService service) {
  return [
    CalendarCreateEventTool(service),
    CalendarUpdateEventTool(service),
    CalendarDeleteEventTool(service),
    CalendarListEventsTool(service),
    CalendarFindFreeTimeTool(service),
    CalendarGetTodayTool(service),
    CalendarGetWeekTool(service),
    CalendarSearchEventsTool(service),
  ];
}
