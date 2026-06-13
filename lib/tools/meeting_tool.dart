import '../core/meeting_assistant.dart';
import 'tool.dart';

List<Tool> getAllMeetingTools(MeetingAssistant assistant) {
  return [
    StartMeetingTool(assistant),
    EndMeetingTool(assistant),
    AddMeetingNoteTool(assistant),
    GetMeetingNotesTool(assistant),
    GetMeetingsTool(assistant),
    UpdateMeetingSummaryTool(assistant),
    DeleteMeetingTool(assistant),
  ];
}

class StartMeetingTool extends Tool {
  final MeetingAssistant _assistant;

  StartMeetingTool(this._assistant)
      : super(
          name: 'start_meeting',
          description: 'Start a new meeting and begin taking notes.',
          parameters: [
            const ToolParameter(
              name: 'title',
              description: 'Title of the meeting',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'participants',
              description: 'JSON array of participant names',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final participants = params['participants'] != null
        ? List<String>.from(params['participants'])
        : <String>[];
    final meetingId = await _assistant.startMeeting(
      title: params['title'],
      participants: participants,
    );
    return ToolResult.success(
      'Meeting started',
      metadata: {'meetingId': meetingId},
    );
  }
}

class EndMeetingTool extends Tool {
  final MeetingAssistant _assistant;

  EndMeetingTool(this._assistant)
      : super(
          name: 'end_meeting',
          description: 'End the current meeting.',
          parameters: [
            const ToolParameter(
              name: 'meeting_id',
              description: 'ID of the meeting to end',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _assistant.endMeeting(params['meeting_id']);
    return ToolResult.success('Meeting ended');
  }
}

class AddMeetingNoteTool extends Tool {
  final MeetingAssistant _assistant;

  AddMeetingNoteTool(this._assistant)
      : super(
          name: 'add_meeting_note',
          description: 'Add a note to the current meeting.',
          parameters: [
            const ToolParameter(
              name: 'meeting_id',
              description: 'ID of the meeting',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'content',
              description: 'Note content',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'speaker',
              description: 'Name of the speaker (optional)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _assistant.addNote(
      meetingId: params['meeting_id'],
      content: params['content'],
      speaker: params['speaker'],
    );
    return ToolResult.success('Note added');
  }
}

class GetMeetingNotesTool extends Tool {
  final MeetingAssistant _assistant;

  GetMeetingNotesTool(this._assistant)
      : super(
          name: 'get_meeting_notes',
          description: 'Get all notes from a meeting.',
          parameters: [
            const ToolParameter(
              name: 'meeting_id',
              description: 'ID of the meeting',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final notes = await _assistant.getNotes(params['meeting_id']);
    final data = notes.map((n) => {
      'content': n.content,
      'speaker': n.speaker,
      'timestamp': n.timestamp.toIso8601String(),
    }).toList();
    return ToolResult.success(data, metadata: {'count': data.length});
  }
}

class GetMeetingsTool extends Tool {
  final MeetingAssistant _assistant;

  GetMeetingsTool(this._assistant)
      : super(
          name: 'get_meetings',
          description: 'Get a list of recent meetings.',
          parameters: [
            const ToolParameter(
              name: 'limit',
              description: 'Maximum number of meetings to return',
              type: ToolParameterType.integer,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final meetings = await _assistant.getMeetings(
      limit: params['limit'] ?? 20,
    );
    final data = meetings.map((m) => {
      'id': m.id,
      'title': m.title,
      'startTime': m.startTime.toIso8601String(),
      'endTime': m.endTime?.toIso8601String(),
      'participants': m.participants,
      'summary': m.summary,
    }).toList();
    return ToolResult.success(data, metadata: {'count': data.length});
  }
}

class UpdateMeetingSummaryTool extends Tool {
  final MeetingAssistant _assistant;

  UpdateMeetingSummaryTool(this._assistant)
      : super(
          name: 'update_meeting_summary',
          description: 'Update the summary of a meeting.',
          parameters: [
            const ToolParameter(
              name: 'meeting_id',
              description: 'ID of the meeting',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'summary',
              description: 'Meeting summary',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _assistant.updateSummary(params['meeting_id'], params['summary']);
    return ToolResult.success('Summary updated');
  }
}

class DeleteMeetingTool extends Tool {
  final MeetingAssistant _assistant;

  DeleteMeetingTool(this._assistant)
      : super(
          name: 'delete_meeting',
          description: 'Delete a meeting and all its notes.',
          parameters: [
            const ToolParameter(
              name: 'meeting_id',
              description: 'ID of the meeting to delete',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _assistant.deleteMeeting(params['meeting_id']);
    return ToolResult.success('Meeting deleted');
  }
}
