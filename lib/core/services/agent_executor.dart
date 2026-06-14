import 'dart:async';
import '../../tools/tool_manager.dart';
import '../../tools/tool.dart' as tool;
import '../ai_engine.dart';
import '../models/activity_event.dart';
import 'timeline_service.dart';
import 'orb_state_manager.dart';

class ExecutionStep {
  final String type;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ExecutionStep({
    required this.type,
    required this.message,
    required this.timestamp,
    this.metadata,
  });
}

class ExecutionResult {
  final bool success;
  final String? response;
  final String? error;
  final List<ExecutionStep> steps;
  final List<Map<String, dynamic>> toolCalls;
  final Duration duration;

  const ExecutionResult({
    required this.success,
    this.response,
    this.error,
    required this.steps,
    required this.toolCalls,
    required this.duration,
  });
}

class AgentExecutor {
  final AIEngine _aiEngine;
  final ToolManager _toolManager;
  final TimelineService _timeline;
  final OrbStateManager _orb;
  final List<ExecutionStep> _steps = [];
  final StreamController<ExecutionStep> _stepController =
      StreamController<ExecutionStep>.broadcast();

  AgentExecutor({
    required AIEngine aiEngine,
    required ToolManager toolManager,
    required TimelineService timeline,
    required OrbStateManager orb,
  })  : _aiEngine = aiEngine,
        _toolManager = toolManager,
        _timeline = timeline,
        _orb = orb;

  Stream<ExecutionStep> get stepStream => _stepController.stream;
  List<ExecutionStep> get steps => List.unmodifiable(_steps);

  void _addStep(String type, String message, {Map<String, dynamic>? metadata}) {
    final step = ExecutionStep(
      type: type,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    _steps.insert(0, step);
    _stepController.add(step);
  }

  Future<ExecutionResult> execute({
    required String task,
    required String agentName,
    String? systemPrompt,
    int maxIterations = 5,
  }) async {
    _steps.clear();
    final stopwatch = Stopwatch()..start();

    _orb.requestThinking('executor:$agentName');
    _addStep('thinking', '$agentName is thinking...');

    try {
      // Set tool definitions from ToolManager (real OpenAI function format)
      final toolDefs = _toolManager.getToolDefinitions();
      _aiEngine.setToolDefinitions(toolDefs);
      _addStep('info', 'Loaded ${toolDefs.length} tools');

      if (systemPrompt != null) {
        _aiEngine.setSystemPrompt(systemPrompt);
      }

      _addStep('thinking', 'Sending task to AI...');

      // Execute with real tool calling loop
      final result = await _aiEngine.sendMessageWithTools(
        task,
        maxIterations: maxIterations,
        onToolCall: (name, args) async {
          return _executeTool(name, args);
        },
      );

      stopwatch.stop();
      _orb.releaseThinking('executor:$agentName');

      final success = result['success'] as bool? ?? false;
      final response = result['response'] as String?;
      final error = result['error'] as String?;
      final rawToolCalls = result['toolCalls'] as List<dynamic>? ?? [];
      final toolCalls = rawToolCalls
          .map((tc) => {
                'name': tc.name,
                'arguments': tc.arguments,
              })
          .toList();

      if (success) {
        _addStep('response', response ?? 'Task completed');
      } else {
        _addStep('error', error ?? 'Unknown error');
      }

      // Log to timeline
      await _timeline.log(
        source: agentName,
        type: success ? ActivityType.agentCompleted : ActivityType.agentFailed,
        title: success ? 'Task Completed' : 'Task Failed',
        description: task.length > 100 ? '${task.substring(0, 100)}...' : task,
        metadata: {
          'toolCalls': toolCalls.length,
          'steps': _steps.length,
          'duration': stopwatch.elapsedMilliseconds,
        },
      );

      return ExecutionResult(
        success: success,
        response: response,
        error: error,
        steps: List.from(_steps),
        toolCalls: toolCalls,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      _orb.releaseThinking('executor:$agentName');
      _addStep('error', 'Execution failed: $e');

      await _timeline.log(
        source: agentName,
        type: ActivityType.agentFailed,
        title: 'Task Failed',
        description: e.toString(),
      );

      return ExecutionResult(
        success: false,
        error: e.toString(),
        steps: List.from(_steps),
        toolCalls: [],
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<tool.ToolResult> _executeTool(String name, Map<String, dynamic> args) async {
    _addStep('tool_call', 'Executing: $name', metadata: {'args': args});

    try {
      final result = await _toolManager.executeTool(name, args);

      if (result.success) {
        final dataStr = result.data?.toString() ?? 'success';
        final truncated = dataStr.length > 300
            ? '${dataStr.substring(0, 300)}...'
            : dataStr;
        _addStep('tool_result', '$name → $truncated');
      } else {
        _addStep('error', '$name failed: ${result.error}');
      }

      return result;
    } catch (e) {
      _addStep('error', '$name exception: $e');
      return tool.ToolResult.error('Tool execution failed: $e');
    }
  }

  void dispose() {
    _stepController.close();
  }
}
