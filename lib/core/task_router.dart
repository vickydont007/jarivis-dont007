import 'dart:async';
import 'agent_network.dart';

enum TaskPriority {
  low,
  medium,
  high,
  critical,
}

class RoutedTask {
  final String id;
  final String description;
  final TaskPriority priority;
  final String? targetAgentId;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  String? result;
  String? error;

  RoutedTask({
    required this.id,
    required this.description,
    this.priority = TaskPriority.medium,
    this.targetAgentId,
  }) : createdAt = DateTime.now();

  bool get isPending => startedAt == null;
  bool get isRunning => startedAt != null && completedAt == null;
  bool get isCompleted => completedAt != null && error == null;
  bool get isFailed => error != null;

  void start() => startedAt = DateTime.now();
  void complete(String result) {
    this.result = result;
    completedAt = DateTime.now();
  }
  void fail(String error) {
    this.error = error;
    completedAt = DateTime.now();
  }
}

class TaskRouter {
  final AgentNetwork _network;
  final List<RoutedTask> _taskQueue = [];
  final StreamController<RoutedTask> _taskController =
      StreamController<RoutedTask>.broadcast();

  Stream<RoutedTask> get taskStream => _taskController.stream;
  List<RoutedTask> get pendingTasks =>
      _taskQueue.where((t) => t.isPending).toList();
  List<RoutedTask> get runningTasks =>
      _taskQueue.where((t) => t.isRunning).toList();

  TaskRouter(this._network);

  RoutedTask routeTask(String description, {TaskPriority priority = TaskPriority.medium}) {
    final agentId = _network.routeTask(description);

    final task = RoutedTask(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      description: description,
      priority: priority,
      targetAgentId: agentId.isNotEmpty ? agentId : null,
    );

    _taskQueue.add(task);
    _taskController.add(task);

    return task;
  }

  RoutedTask? getNextTask() {
    final pending = _taskQueue.where((t) => t.isPending).toList();
    if (pending.isEmpty) return null;

    pending.sort((a, b) {
      final aPriority = a.priority.index;
      final bPriority = b.priority.index;
      if (aPriority != bPriority) return bPriority - aPriority;
      return a.createdAt.compareTo(b.createdAt);
    });

    return pending.first;
  }

  void startTask(String taskId) {
    final task = _taskQueue.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    task.start();

    if (task.targetAgentId != null) {
      final agent = _network.getAgentById(task.targetAgentId!);
      agent?.markBusy();
    }

    _taskController.add(task);
  }

  void completeTask(String taskId, String result) {
    final task = _taskQueue.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    task.complete(result);

    if (task.targetAgentId != null) {
      final agent = _network.getAgentById(task.targetAgentId!);
      agent?.markComplete(success: true, result: result);
    }

    _taskController.add(task);
  }

  void failTask(String taskId, String error) {
    final task = _taskQueue.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    task.fail(error);

    if (task.targetAgentId != null) {
      final agent = _network.getAgentById(task.targetAgentId!);
      agent?.markComplete(success: false);
    }

    _taskController.add(task);
  }

  List<RoutedTask> getTasksForAgent(String agentId) {
    return _taskQueue.where((t) => t.targetAgentId == agentId).toList();
  }

  void clearCompleted() {
    _taskQueue.removeWhere((t) => t.isCompleted || t.isFailed);
  }

  void dispose() {
    _taskController.close();
  }
}
