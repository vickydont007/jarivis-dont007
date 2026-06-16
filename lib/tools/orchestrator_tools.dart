import '../core/services/multi_agent_orchestrator.dart';
import '../core/models/workflow.dart';
import 'tool.dart';

class OrchestratorCreateWorkflowTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorCreateWorkflowTool(this._orchestrator)
      : super(
          name: 'orchestrator_create_workflow',
          description: 'Create and execute a multi-agent workflow for a complex goal. The orchestrator will decompose the goal, select agents, and coordinate execution.',
          parameters: [
            const ToolParameter(name: 'goal', description: 'The high-level goal to accomplish', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'context', description: 'Additional context as JSON key-value pairs', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final goal = params['goal'] as String;
      final contextStr = params['context'] as String?;
      Map<String, dynamic>? context;
      if (contextStr != null && contextStr.isNotEmpty) {
        try {
          context = Map<String, dynamic>.from(
            (Map<String, dynamic>.from({}))..addAll(
              Map<String, dynamic>.from({'key': contextStr}),
            ),
          );
        } catch (_) {}
      }

      final result = await _orchestrator.executeGoal(goal, context: context);

      final buffer = StringBuffer('🔄 Workflow ${result.status.name}\n');
      buffer.writeln('Goal: ${result.goal}');
      buffer.writeln('Progress: ${(result.progress * 100).round()}% (${result.completedTasks}/${result.totalTasks} tasks)');

      if (result.status == WorkflowStatus.completed) {
        buffer.writeln('\n✅ Completed in ${result.duration.inSeconds}s');
      } else if (result.status == WorkflowStatus.failed) {
        buffer.writeln('\n❌ Failed: ${result.failedTasks} tasks failed');
      }

      if (result.results.isNotEmpty) {
        buffer.writeln('\nResults:');
        for (final entry in result.results.entries) {
          final value = entry.value.toString();
          buffer.writeln('  ${entry.key}: ${value.length > 100 ? "${value.substring(0, 100)}..." : value}');
        }
      }

      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Workflow failed: $e');
    }
  }
}

class OrchestratorStatusTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorStatusTool(this._orchestrator)
      : super(
          name: 'orchestrator_status',
          description: 'Get the status of a specific workflow or all active workflows',
          parameters: [
            const ToolParameter(name: 'workflow_id', description: 'Workflow ID (optional, shows all if omitted)', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final workflowId = params['workflow_id'] as String?;

      if (workflowId != null && workflowId.isNotEmpty) {
        final result = await _orchestrator.getWorkflowResult(workflowId);
        if (result != null) {
          return ToolResult.success(
            'Workflow: ${result.goal}\n'
            'Status: ${result.status.name}\n'
            'Progress: ${(result.progress * 100).round()}%\n'
            'Tasks: ${result.completedTasks}/${result.totalTasks} completed, ${result.failedTasks} failed\n'
            'Duration: ${result.duration.inSeconds}s',
          );
        }

        final messages = await _orchestrator.getWorkflowMessages(workflowId);
        if (messages.isNotEmpty) {
          final buffer = StringBuffer('Workflow $workflowId messages:\n');
          for (final msg in messages) {
            buffer.writeln('  [${msg['message_type']}] ${msg['agent_type'] ?? ''} - ${msg['timestamp']}');
          }
          return ToolResult.success(buffer.toString());
        }

        return ToolResult.error('Workflow not found: $workflowId');
      }

      final active = await _orchestrator.getActiveWorkflows();
      if (active.isEmpty) {
        return ToolResult.success('No active workflows.');
      }

      final buffer = StringBuffer('Active Workflows (${active.length}):\n\n');
      for (final wf in active) {
        buffer.writeln('• ${wf.goal}');
        buffer.writeln('  Status: ${wf.status.name} | Progress: ${(wf.progress * 100).round()}%');
        buffer.writeln('  Tasks: ${wf.completedCount}/${wf.tasks.length} completed');
        buffer.writeln('');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to get status: $e');
    }
  }
}

class OrchestratorCancelTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorCancelTool(this._orchestrator)
      : super(
          name: 'orchestrator_cancel',
          description: 'Cancel a running workflow',
          parameters: [
            const ToolParameter(name: 'workflow_id', description: 'ID of the workflow to cancel', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final workflowId = params['workflow_id'] as String;
      _orchestrator.cancelWorkflow(workflowId);
      return ToolResult.success('Workflow $workflowId cancelled.');
    } catch (e) {
      return ToolResult.error('Failed to cancel workflow: $e');
    }
  }
}

class OrchestratorResumeTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorResumeTool(this._orchestrator)
      : super(
          name: 'orchestrator_resume',
          description: 'Resume a paused workflow by re-executing pending tasks',
          parameters: [
            const ToolParameter(name: 'workflow_id', description: 'ID of the workflow to resume', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final workflowId = params['workflow_id'] as String;
      final wf = await _orchestrator.database.getWorkflow(workflowId);
      if (wf == null) return ToolResult.error('Workflow not found: $workflowId');

      if (wf.status != WorkflowStatus.paused && wf.status != WorkflowStatus.failed) {
        return ToolResult.error('Workflow is ${wf.status.name}, only paused/failed workflows can be resumed');
      }

      wf.status = WorkflowStatus.running;
      for (final task in wf.tasks) {
        if (task.status == TaskStatus.failed) {
          task.status = TaskStatus.pending;
          task.retryCount = 0;
          task.error = null;
        }
      }

      final result = await _orchestrator.engine.execute(wf);
      return ToolResult.success('Workflow resumed: ${result.summary}');
    } catch (e) {
      return ToolResult.error('Failed to resume workflow: $e');
    }
  }
}

class OrchestratorListWorkflowsTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorListWorkflowsTool(this._orchestrator)
      : super(
          name: 'orchestrator_list_workflows',
          description: 'List recent workflows with their status',
          parameters: [
            const ToolParameter(name: 'limit', description: 'Number of workflows to show (default: 10)', type: ToolParameterType.integer),
            const ToolParameter(name: 'status', description: 'Filter by status: running, completed, failed, cancelled', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final limit = (params['limit'] as int?) ?? 10;
      final statusStr = params['status'] as String?;
      WorkflowStatus? status;
      if (statusStr != null) {
        status = WorkflowStatus.values.firstWhere(
          (s) => s.name == statusStr,
          orElse: () => WorkflowStatus.running,
        );
      }

      final workflows = await _orchestrator.getRecentWorkflows(limit: limit);
      final filtered = status != null
          ? workflows.where((w) => w.status == status).toList()
          : workflows;

      if (filtered.isEmpty) {
        return ToolResult.success('No workflows found.');
      }

      final buffer = StringBuffer('Recent Workflows (${filtered.length}):\n\n');
      for (final wf in filtered) {
        final icon = wf.status == WorkflowStatus.completed ? '✅'
            : wf.status == WorkflowStatus.failed ? '❌'
            : wf.status == WorkflowStatus.running ? '🔄'
            : wf.status == WorkflowStatus.cancelled ? '🚫' : '⏳';
        buffer.writeln('$icon ${wf.goal}');
        buffer.writeln('  Status: ${wf.status.name} | Tasks: ${wf.completedCount}/${wf.tasks.length}');
        buffer.writeln('  Created: ${wf.createdAt.toLocal()}');
        buffer.writeln('');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to list workflows: $e');
    }
  }
}

class OrchestratorShowAgentsTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorShowAgentsTool(this._orchestrator)
      : super(
          name: 'orchestrator_show_agents',
          description: 'Show all registered agents and their capabilities',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final agents = _orchestrator.registry.agents;
      final buffer = StringBuffer('Registered Agents (${agents.length}):\n\n');
      for (final agent in agents) {
        buffer.writeln('${agent.icon} ${agent.name} (${agent.type})');
        buffer.writeln('  ${agent.description}');
        for (final cap in agent.capabilities) {
          buffer.writeln('  • ${cap.name}: ${cap.toolNames.join(", ")}');
        }
        buffer.writeln('');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to show agents: $e');
    }
  }
}

class OrchestratorShowTasksTool extends Tool {
  final MultiAgentOrchestrator _orchestrator;
  OrchestratorShowTasksTool(this._orchestrator)
      : super(
          name: 'orchestrator_show_tasks',
          description: 'Show detailed task breakdown for a specific workflow',
          parameters: [
            const ToolParameter(name: 'workflow_id', description: 'Workflow ID to show tasks for', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final workflowId = params['workflow_id'] as String;
      final wf = await _orchestrator.database.getWorkflow(workflowId);
      if (wf == null) return ToolResult.error('Workflow not found: $workflowId');

      final buffer = StringBuffer('Workflow: ${wf.goal}\n');
      buffer.writeln('Status: ${wf.status.name} | Progress: ${(wf.progress * 100).round()}%\n');
      buffer.writeln('Tasks (${wf.tasks.length}):\n');

      for (final task in wf.tasks) {
        final icon = task.status == TaskStatus.completed ? '✅'
            : task.status == TaskStatus.failed ? '❌'
            : task.status == TaskStatus.running ? '🔄'
            : task.status == TaskStatus.retrying ? '🔁' : '⏳';
        buffer.writeln('$icon [${task.id}] ${task.description}');
        buffer.writeln('   Agent: ${task.agentType} | Tool: ${task.toolName}');
        buffer.writeln('   Status: ${task.status.name}');
        if (task.result != null) {
          final result = task.result!;
          buffer.writeln('   Result: ${result.length > 80 ? "${result.substring(0, 80)}..." : result}');
        }
        if (task.error != null) {
          buffer.writeln('   Error: ${task.error}');
        }
        if (task.dependsOn.isNotEmpty) {
          buffer.writeln('   Depends on: ${task.dependsOn.join(", ")}');
        }
        buffer.writeln('');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to show tasks: $e');
    }
  }
}

List<Tool> getAllOrchestratorTools(MultiAgentOrchestrator orchestrator) {
  return [
    OrchestratorCreateWorkflowTool(orchestrator),
    OrchestratorStatusTool(orchestrator),
    OrchestratorCancelTool(orchestrator),
    OrchestratorResumeTool(orchestrator),
    OrchestratorListWorkflowsTool(orchestrator),
    OrchestratorShowAgentsTool(orchestrator),
    OrchestratorShowTasksTool(orchestrator),
  ];
}
