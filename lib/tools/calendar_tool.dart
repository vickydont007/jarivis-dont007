import 'dart:io';
import 'tool.dart';

class CalendarEventsTool extends Tool {
  CalendarEventsTool()
      : super(
          name: 'calendar_events',
          description: 'List upcoming calendar events',
          parameters: [
            const ToolParameter(
              name: 'days',
              description: 'Number of days to look ahead (default: 7)',
              type: ToolParameterType.integer,
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final days = params['days'] as int? ?? 7;

    try {
      final script = '''
tell application "Calendar"
  activate
  set eventList to {}
  set startDate to current date
  set endDate to startDate + ($days * days)
  repeat with cal in calendars
    try
      set events to (every event of cal whose start date ≥ startDate and start date ≤ endDate)
      repeat with evt in events
        set end of eventList to (summary of evt & " ||| " & (start date of evt as string) & " ||| " & (end date of evt as string) & " ||| " & (description of evt as string))
      end repeat
    end try
  end repeat
  set AppleScript's text item delimiters to "###"
  if (count of eventList) = 0 then return "NO_EVENTS"
  return eventList as string
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty || output == 'NO_EVENTS') {
          return ToolResult.success('No upcoming events in the next $days days.');
        }

        final events = output.split('###').where((s) => s.trim().isNotEmpty).map((line) {
          final parts = line.split(' ||| ');
          return {
            'title': parts.isNotEmpty ? parts[0].trim() : '',
            'start': parts.length > 1 ? parts[1].trim() : '',
            'end': parts.length > 2 ? parts[2].trim() : '',
            'description': parts.length > 3 ? parts[3].trim() : '',
          };
        }).toList();

        return ToolResult.success(events);
      }
      return ToolResult.error('Calendar error: ${result.stderr.toString().trim()}');
    } catch (e) {
      return ToolResult.error('Failed to get calendar events: $e');
    }
  }
}

class CalendarCreateTool extends Tool {
  CalendarCreateTool()
      : super(
          name: 'calendar_create',
          description: 'Create a new calendar event in macOS Calendar app',
          parameters: [
            const ToolParameter(
              name: 'title',
              description: 'Event title',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'date',
              description: 'Event date as YYYY-MM-DD format (e.g., "2026-06-20")',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'time',
              description: 'Event time as HH:MM in 24h format (e.g., "10:00" or "14:30")',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'description',
              description: 'Event description',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final title = params['title'] as String?;
    final dateStr = params['date'] as String?;
    final time = params['time'] as String? ?? '10:00';
    final description = params['description'] as String? ?? '';

    if (title == null || dateStr == null) {
      return ToolResult.error('title and date are required');
    }

    try {
      // Parse YYYY-MM-DD
      final parts = dateStr.split('-');
      if (parts.length != 3) {
        return ToolResult.error('Date must be in YYYY-MM-DD format (e.g., "2026-06-20")');
      }
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      // Parse HH:MM
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      final script = '''
tell application "Calendar"
  activate
  set cal to calendar "Home"
  set evtDate to current date
  set year of evtDate to $year
  set month of evtDate to $month
  set day of evtDate to $day
  set hours of evtDate to $hour
  set minutes of evtDate to $minute
  set seconds of evtDate to 0
  set endDate to evtDate + (1 * hours)
  set newEvt to make new event at end of events of cal with properties {summary:"$title", start date:evtDate, end date:endDate, description:"$description"}
  return "OK"
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return ToolResult.success('Event "$title" created for $dateStr at $time');
      }
      final err = result.stderr.toString().trim();
      if (err.contains('not found') || err.contains('Can\'t continue')) {
        return ToolResult.error('Calendar app not available. Please open Calendar.app first.');
      }
      return ToolResult.error('Calendar error: $err');
    } catch (e) {
      return ToolResult.error('Failed to create event: $e');
    }
  }
}

class CalendarDeleteTool extends Tool {
  CalendarDeleteTool()
      : super(
          name: 'calendar_delete',
          description: 'Delete a calendar event by title',
          parameters: [
            const ToolParameter(
              name: 'title',
              description: 'Title of the event to delete',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final title = params['title'] as String?;

    if (title == null) {
      return ToolResult.error('title is required to identify the event');
    }

    try {
      final script = '''
tell application "Calendar"
  activate
  set deletedCount to 0
  repeat with cal in calendars
    try
      set events to (every event of cal whose summary is "$title")
      repeat with evt in events
        delete evt
        set deletedCount to deletedCount + 1
      end repeat
    end try
  end repeat
  return deletedCount
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        final count = result.stdout.toString().trim();
        if (count == '0') {
          return ToolResult.success('No event found with title "$title"');
        }
        return ToolResult.success('Deleted $count event(s) with title "$title"');
      }
      return ToolResult.error('Calendar error: ${result.stderr.toString().trim()}');
    } catch (e) {
      return ToolResult.error('Failed to delete event: $e');
    }
  }
}

List<Tool> getAllCalendarTools() {
  return [
    CalendarEventsTool(),
    CalendarCreateTool(),
    CalendarDeleteTool(),
  ];
}
