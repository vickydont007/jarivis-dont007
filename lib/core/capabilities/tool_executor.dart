import 'dart:async';
import 'tool_registry.dart';
import '../services/timeline_service.dart';
import '../services/orb_state_manager.dart';
import '../models/activity_event.dart';

class ToolExecution {
  final String id;
  final String toolName;
  final Map<String, dynamic> params;
  final DateTime startedAt;
  DateTime? completedAt;
  ToolResult? result;

  ToolExecution({
    required this.id,
    required this.toolName,
    required this.params,
    required this.startedAt,
  });

  Duration get duration =>
      (completedAt ?? DateTime.now()).difference(startedAt);

  bool get isRunning => completedAt == null;
}

class ToolExecutor {
  final ToolRegistry _registry;
  final TimelineService _timeline;
  final OrbStateManager _orb;
  final List<ToolExecution> _history = [];
  final StreamController<ToolExecution> _executionController =
      StreamController<ToolExecution>.broadcast();

  ToolExecutor({
    required ToolRegistry registry,
    required TimelineService timeline,
    required OrbStateManager orb,
  })  : _registry = registry,
        _timeline = timeline,
        _orb = orb;

  Stream<ToolExecution> get executions => _executionController.stream;
  List<ToolExecution> get history => List.unmodifiable(_history);

  Future<ToolResult> execute(
    String toolName, {
    Map<String, dynamic> params = const {},
  }) async {
    final tool = _registry.getTool(toolName);
    if (tool == null) {
      return ToolResult.failure('Tool not found: $toolName');
    }

    if (!tool.definition.isEnabled) {
      return ToolResult.failure('Tool disabled: $toolName');
    }

    final execution = ToolExecution(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      toolName: toolName,
      params: params,
      startedAt: DateTime.now(),
    );

    _history.insert(0, execution);
    if (_history.length > 100) {
      _history.removeRange(100, _history.length);
    }

    _executionController.add(execution);
    _orb.requestThinking('tool:$toolName');

    await _timeline.log(
      source: 'ToolExecutor',
      type: ActivityType.systemEvent,
      title: 'Tool Execution Started',
      description: 'Executing $toolName',
      metadata: {'tool': toolName, 'params': params},
    );

    final stopwatch = Stopwatch()..start();

    try {
      final result = await tool.handler(params).timeout(
        const Duration(seconds: 60),
        onTimeout: () => ToolResult.failure('Tool execution timeout'),
      );

      stopwatch.stop();
      final timedResult = result.withExecutionTime(stopwatch.elapsed);

      execution.completedAt = DateTime.now();
      execution.result = timedResult;

      _orb.releaseThinking('tool:$toolName');

      await _timeline.log(
        source: 'ToolExecutor',
        type: ActivityType.systemEvent,
        title: timedResult.success
            ? 'Tool Execution Completed'
            : 'Tool Execution Failed',
        description: timedResult.success
            ? '$toolName completed in ${stopwatch.elapsedMilliseconds}ms'
            : '$toolName failed: ${timedResult.error}',
        metadata: {
          'tool': toolName,
          'success': timedResult.success,
          'duration': stopwatch.elapsedMilliseconds,
        },
      );

      _executionController.add(execution);
      return timedResult;
    } catch (e) {
      stopwatch.stop();

      execution.completedAt = DateTime.now();
      execution.result = ToolResult.failure(e.toString());

      _orb.releaseThinking('tool:$toolName');

      await _timeline.log(
        source: 'ToolExecutor',
        type: ActivityType.systemEvent,
        title: 'Tool Execution Error',
        description: '$toolName error: $e',
        metadata: {'tool': toolName, 'error': e.toString()},
      );

      return ToolResult.failure(e.toString());
    }
  }

  Future<List<ToolResult>> executeBatch(
    List<Map<String, dynamic>> operations,
  ) async {
    final results = <ToolResult>[];
    for (final op in operations) {
      final toolName = op['tool'] as String;
      final params = Map<String, dynamic>.from(op['params'] ?? {});
      final result = await execute(toolName, params: params);
      results.add(result);
    }
    return results;
  }

  List<ToolExecution> getRecentExecutions({int limit = 20}) {
    return _history.take(limit).toList();
  }

  Map<String, dynamic> getStats() {
    final total = _history.length;
    final successful = _history.where((e) => e.result?.success == true).length;
    final failed = _history.where((e) => e.result?.success == false).length;
    final running = _history.where((e) => e.isRunning).length;

    return {
      'total': total,
      'successful': successful,
      'failed': failed,
      'running': running,
      'successRate': total > 0 ? (successful / total * 100).round() : 0,
    };
  }

  void clearHistory() {
    _history.clear();
  }

  void dispose() {
    _executionController.close();
  }
}
