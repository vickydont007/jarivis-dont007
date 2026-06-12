import 'dart:async';
import 'tool.dart';
import 'tool_registry.dart';

class ToolExecution {
  final String toolName;
  final Map<String, dynamic> params;
  final DateTime startTime;
  DateTime? endTime;
  ToolResult? result;
  String? error;

  ToolExecution({
    required this.toolName,
    required this.params,
    required this.startTime,
  });

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  bool get isCompleted => result != null || error != null;
}

class ToolExecutor {
  final ToolRegistry _registry;
  final Duration defaultTimeout;
  final int maxConcurrent;
  int _runningCount = 0;
  final List<ToolExecution> _history = [];
  final StreamController<ToolExecution> _executionController =
      StreamController.broadcast();

  ToolExecutor({
    required ToolRegistry registry,
    this.defaultTimeout = const Duration(seconds: 30),
    this.maxConcurrent = 5,
  }) : _registry = registry;

  Stream<ToolExecution> get executionStream => _executionController.stream;
  List<ToolExecution> get history => List.unmodifiable(_history);

  Future<ToolResult> execute(
    String toolName,
    Map<String, dynamic> params, {
    Duration? timeout,
  }) async {
    final tool = _registry.getTool(toolName);
    if (tool == null) {
      return ToolResult.error('Tool not found: $toolName');
    }

    if (_runningCount >= maxConcurrent) {
      return ToolResult.error('Max concurrent executions reached');
    }

    final execution = ToolExecution(
      toolName: toolName,
      params: params,
      startTime: DateTime.now(),
    );
    _history.add(execution);
    _executionController.add(execution);

    _runningCount++;
    try {
      final result = await _executeWithTimeout(
        tool,
        params,
        timeout ?? defaultTimeout,
      );
      execution.result = result;
      execution.endTime = DateTime.now();
      return result;
    } catch (e) {
      final error = ToolResult.error(e.toString());
      execution.result = error;
      execution.error = e.toString();
      execution.endTime = DateTime.now();
      return error;
    } finally {
      _runningCount--;
      _executionController.add(execution);
    }
  }

  Future<ToolResult> _executeWithTimeout(
    Tool tool,
    Map<String, dynamic> params,
    Duration timeout,
  ) async {
    try {
      final result = await Future(() => tool.execute(params)).timeout(timeout);
      if (result is Future) {
        return await result;
      }
      return result;
    } on TimeoutException {
      return ToolResult.error(
        'Tool execution timed out after ${timeout.inSeconds}s',
      );
    }
  }

  Future<List<ToolResult>> executeBatch(
    List<Map<String, dynamic>> calls,
  ) async {
    final results = <Future<ToolResult>>[];
    for (final call in calls) {
      final toolName = call['tool'] as String;
      final params = call['params'] as Map<String, dynamic>? ?? {};
      results.add(execute(toolName, params));
    }
    return Future.wait(results);
  }

  void clearHistory() {
    _history.clear();
  }

  int get runningCount => _runningCount;
  bool get canExecute => _runningCount < maxConcurrent;

  void dispose() {
    _executionController.close();
  }
}
