import '../core/screen_recording.dart';
import 'tool.dart';

List<Tool> getAllRecordingTools(ScreenRecording recording) {
  return [
    StartRecordingTool(recording),
    StopRecordingTool(recording),
    PauseRecordingTool(recording),
    ResumeRecordingTool(recording),
    RecordingStatusTool(recording),
  ];
}

class StartRecordingTool extends Tool {
  final ScreenRecording _recording;

  StartRecordingTool(this._recording)
      : super(
          name: 'start_recording',
          description: 'Start recording the screen.',
          parameters: [
            const ToolParameter(
              name: 'output_path',
              description: 'Optional path to save the recording',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _recording.startRecording(outputPath: params['output_path']);
    return ToolResult.success('Recording started');
  }
}

class StopRecordingTool extends Tool {
  final ScreenRecording _recording;

  StopRecordingTool(this._recording)
      : super(
          name: 'stop_recording',
          description: 'Stop the current screen recording.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = await _recording.stopRecording();
    if (path != null) {
      return ToolResult.success(
        'Recording stopped',
        metadata: {'path': path},
      );
    }
    return ToolResult.success('Recording stopped');
  }
}

class PauseRecordingTool extends Tool {
  final ScreenRecording _recording;

  PauseRecordingTool(this._recording)
      : super(
          name: 'pause_recording',
          description: 'Pause the current screen recording.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _recording.pauseRecording();
    return ToolResult.success('Recording paused');
  }
}

class ResumeRecordingTool extends Tool {
  final ScreenRecording _recording;

  ResumeRecordingTool(this._recording)
      : super(
          name: 'resume_recording',
          description: 'Resume the paused screen recording.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _recording.resumeRecording();
    return ToolResult.success('Recording resumed');
  }
}

class RecordingStatusTool extends Tool {
  final ScreenRecording _recording;

  RecordingStatusTool(this._recording)
      : super(
          name: 'recording_status',
          description: 'Get the current recording status.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final info = _recording.currentInfo;
    return ToolResult.success({
      'isRecording': info.isRecording,
      'duration': info.duration.inSeconds,
      'outputPath': info.outputPath,
    });
  }
}
