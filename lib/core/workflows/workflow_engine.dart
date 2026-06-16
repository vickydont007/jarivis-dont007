import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/workflow.dart';
import '../services/agent_message_bus.dart';
import '../workflows/workflow_database.dart';
import '../../tools/tool_manager.dart';

class WorkflowEngine {
  final ToolManager _toolManager;
  final AgentMessageBus _messageBus;
  final WorkflowDatabase _db;
  static const _uuid = Uuid();

  final Map<String, Completer<WorkflowResult>> _activeWorkflows = {};
  final Map<String, bool> _cancelledWorkflows = {};

  WorkflowEngine({
    required ToolManager toolManager,
    required AgentMessageBus messageBus,
    WorkflowDatabase? db,
  })  : _toolManager = toolManager,
        _messageBus = messageBus,
        _db = db ?? WorkflowDatabase();

  ToolManager get toolManager => _toolManager;
  AgentMessageBus get messageBus => _messageBus;
  WorkflowDatabase get database => _db;

  Future<WorkflowResult> execute(Workflow workflow) async {
    final completer = Completer<WorkflowResult>();
    _activeWorkflows[workflow.id] = completer;
    _cancelledWorkflows[workflow.id] = false;

    workflow.status = WorkflowStatus.running;
    workflow.startedAt = DateTime.now();
    await _db.saveWorkflow(workflow);

    _messageBus.publish(WorkflowMessage(
      id: _uuid.v4(),
      workflowId: workflow.id,
      type: WorkflowMessageType.workflowStarted,
      data: {'goal': workflow.goal},
      timestamp: DateTime.now(),
    ));

    try {
      await _executeTasks(workflow);

      if (_cancelledWorkflows[workflow.id] == true) {
        workflow.status = WorkflowStatus.cancelled;
      } else if (workflow.failedCount > 0 && workflow.completedCount == 0) {
        workflow.status = WorkflowStatus.failed;
        workflow.errorMessage = '${workflow.failedCount} tasks failed';
      } else {
        workflow.status = WorkflowStatus.completed;
      }

      workflow.completedAt = DateTime.now();
      await _db.updateWorkflow(workflow);

      final result = WorkflowResult(
        workflowId: workflow.id,
        goal: workflow.goal,
        status: workflow.status,
        progress: workflow.progress,
        totalTasks: workflow.tasks.length,
        completedTasks: workflow.completedCount,
        failedTasks: workflow.failedCount,
        results: _collectResults(workflow),
        completedAt: workflow.completedAt!,
        duration: workflow.completedAt!.difference(workflow.startedAt!),
      );

      _messageBus.publish(WorkflowMessage(
        id: _uuid.v4(),
        workflowId: workflow.id,
        type: workflow.status == WorkflowStatus.completed
            ? WorkflowMessageType.workflowCompleted
            : WorkflowMessageType.workflowFailed,
        data: result.toJson(),
        timestamp: DateTime.now(),
      ));

      _activeWorkflows.remove(workflow.id);
      _cancelledWorkflows.remove(workflow.id);
      if (!completer.isCompleted) completer.complete(result);
      return result;
    } catch (e) {
      workflow.status = WorkflowStatus.failed;
      workflow.errorMessage = e.toString();
      workflow.completedAt = DateTime.now();
      await _db.updateWorkflow(workflow);

      final result = WorkflowResult(
        workflowId: workflow.id,
        goal: workflow.goal,
        status: WorkflowStatus.failed,
        progress: workflow.progress,
        totalTasks: workflow.tasks.length,
        completedTasks: workflow.completedCount,
        failedTasks: workflow.failedCount,
        completedAt: workflow.completedAt!,
        duration: workflow.completedAt!.difference(workflow.startedAt!),
      );

      _messageBus.publish(WorkflowMessage(
        id: _uuid.v4(),
        workflowId: workflow.id,
        type: WorkflowMessageType.workflowFailed,
        data: {'error': e.toString()},
        timestamp: DateTime.now(),
      ));

      _activeWorkflows.remove(workflow.id);
      _cancelledWorkflows.remove(workflow.id);
      if (!completer.isCompleted) completer.complete(result);
      return result;
    }
  }

  Future<void> _executeTasks(Workflow workflow) async {
    while (workflow.status == WorkflowStatus.running) {
      if (_cancelledWorkflows[workflow.id] == true) break;

      final ready = workflow.readyTasks;
      if (ready.isEmpty) {
        final allDone = workflow.tasks.every((t) =>
            t.status == TaskStatus.completed ||
            t.status == TaskStatus.failed ||
            t.status == TaskStatus.skipped);
        if (allDone) break;

        final stuck = workflow.tasks.any((t) => t.status == TaskStatus.running);
        if (stuck) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        break;
      }

      final futures = ready.map((task) => _executeTask(workflow, task)).toList();
      await Future.wait(futures);
    }
  }

  Future<void> _executeTask(Workflow workflow, WorkflowTask task) async {
    task.status = TaskStatus.running;
    task.startedAt = DateTime.now();
    await _db.updateTask(task);

    _messageBus.publish(WorkflowMessage(
      id: _uuid.v4(),
      workflowId: workflow.id,
      type: WorkflowMessageType.taskStarted,
      taskId: task.id,
      agentType: task.agentType,
      data: {'tool': task.toolName, 'description': task.description},
      timestamp: DateTime.now(),
    ));

    try {
      final resolvedParams = _resolveParameters(task.parameters, workflow);

      final result = await _toolManager.executeTool(task.toolName, resolvedParams)
          .timeout(task.timeout);

      if (result.success) {
        task.status = TaskStatus.completed;
        task.result = result.data;
        task.completedAt = DateTime.now();

        if (task.outputKeys.isNotEmpty) {
          workflow.context[task.outputKeys.first] = result.data;
        }
      } else {
        throw Exception(result.error ?? 'Unknown error');
      }
    } on TimeoutException {
      task.error = 'Task timed out after ${task.timeout.inSeconds}s';
      await _handleTaskFailure(workflow, task);
    } catch (e) {
      task.error = e.toString();
      await _handleTaskFailure(workflow, task);
      return;
    }

    await _db.updateTask(task);
    await _db.updateWorkflow(workflow);

    _messageBus.publish(WorkflowMessage(
      id: _uuid.v4(),
      workflowId: workflow.id,
      type: task.status == TaskStatus.completed
          ? WorkflowMessageType.taskCompleted
          : WorkflowMessageType.taskFailed,
      taskId: task.id,
      agentType: task.agentType,
      data: {
        'tool': task.toolName,
        'result': task.result,
        'error': task.error,
      },
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _handleTaskFailure(Workflow workflow, WorkflowTask task) async {
    if (task.retryCount < task.maxRetries) {
      task.retryCount++;
      task.status = TaskStatus.retrying;
      task.error = '${task.error} (retry ${task.retryCount}/${task.maxRetries})';

      _messageBus.publish(WorkflowMessage(
        id: _uuid.v4(),
        workflowId: workflow.id,
        type: WorkflowMessageType.taskRetrying,
        taskId: task.id,
        agentType: task.agentType,
        data: {'retry': task.retryCount, 'maxRetries': task.maxRetries},
        timestamp: DateTime.now(),
      ));

      await Future.delayed(Duration(seconds: 2 * task.retryCount));
      task.status = TaskStatus.pending;
      await _db.updateTask(task);
    } else {
      task.status = TaskStatus.failed;
      task.completedAt = DateTime.now();
      await _db.updateTask(task);
    }
  }

  Map<String, dynamic> _resolveParameters(Map<String, dynamic> params, Workflow workflow) {
    final resolved = <String, dynamic>{};
    for (final entry in params.entries) {
      var value = entry.value;
      if (value is String && value.startsWith('{{') && value.endsWith('}}')) {
        final key = value.substring(2, value.length - 2);
        value = workflow.context[key] ?? value;
      }
      resolved[entry.key] = value;
    }
    return resolved;
  }

  Map<String, dynamic> _collectResults(Workflow workflow) {
    final results = <String, dynamic>{};
    for (final task in workflow.tasks) {
      if (task.status == TaskStatus.completed && task.result != null) {
        for (final key in task.outputKeys) {
          results[key] = task.result;
        }
        results[task.id] = task.result;
      }
    }
    return results;
  }

  void cancelWorkflow(String workflowId) {
    _cancelledWorkflows[workflowId] = true;
    _messageBus.publish(WorkflowMessage(
      id: _uuid.v4(),
      workflowId: workflowId,
      type: WorkflowMessageType.workflowCancelled,
      timestamp: DateTime.now(),
    ));
  }

  bool isRunning(String workflowId) => _activeWorkflows.containsKey(workflowId);

  Future<WorkflowResult?> getResult(String workflowId) async {
    final completer = _activeWorkflows[workflowId];
    if (completer != null && completer.isCompleted) {
      return completer.future.then((r) => r);
    }
    return null;
  }
}
