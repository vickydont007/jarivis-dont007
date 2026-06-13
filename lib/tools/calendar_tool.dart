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
  set eventList to {}
  set cal to calendar "Home"
  set startDate to current date
  set endDate to startDate + ($days * days)
  set events to (every event of cal whose start date ≥ startDate and start date ≤ endDate)
  repeat with evt in events
    set end of eventList to (summary of evt & " ||| " & (start date of evt as string) & " ||| " & (end date of evt as string) & " ||| " & (description of evt as string))
  end repeat
  set AppleScript's text item delimiters to "###"
  return eventList as string
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty) return ToolResult.success(<dynamic>[]);

        final events = output.split('###').map((line) {
          final parts = line.split(' ||| ');
          return {
            'title': parts.isNotEmpty ? parts[0] : '',
            'start': parts.length > 1 ? parts[1] : '',
            'end': parts.length > 2 ? parts[2] : '',
            'description': parts.length > 3 ? parts[3] : '',
          };
        }).toList();

        return ToolResult.success(events);
      }
      return ToolResult.error(result.stderr.toString());
    } catch (e) {
      return ToolResult.error('Failed to get calendar events: $e');
    }
  }
}

class CalendarCreateTool extends Tool {
  CalendarCreateTool()
      : super(
          name: 'calendar_create',
          description: 'Create a new calendar event',
          parameters: [
            const ToolParameter(
              name: 'title',
              description: 'Event title',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'date',
              description: 'Event date (e.g., "June 15, 2026")',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'time',
              description: 'Event time (e.g., "10:00 AM")',
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
    final time = params['time'] as String?;
    final description = params['description'] as String? ?? '';

    if (title == null || dateStr == null) {
      return ToolResult.error('title and date are required');
    }

    try {
      final timeStr = time != null ? ' at $time' : '';
      final script = '''
tell application "Calendar"
  set cal to calendar "Home"
  set evt to make new event at end of events of cal with properties {summary:"$title", start date:date "$dateStr$timeStr", description:"$description"}
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return ToolResult.success('Event "$title" created for $dateStr');
      }
      return ToolResult.error(result.stderr.toString());
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
  set cal to calendar "Home"
  set events to (every event of cal whose summary is "$title")
  repeat with evt in events
    delete evt
  end repeat
end tell
''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return ToolResult.success('Event "$title" deleted');
      }
      return ToolResult.error(result.stderr.toString());
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
