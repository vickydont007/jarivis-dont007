import 'dart:async';

enum StepType {
  toolCall,
  condition,
  loop,
  delay,
  parallel,
  transform,
}

class WorkflowStep {
  final String id;
  final String name;
  final StepType type;
  final Map<String, dynamic> config;
  final List<String> nextSteps;
  final String? condition;

  WorkflowStep({
    required this.id,
    required this.name,
    required this.type,
    this.config = const {},
    this.nextSteps = const [],
    this.condition,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'config': config,
    'next_steps': nextSteps,
    'condition': condition,
  };

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      id: json['id'],
      name: json['name'],
      type: StepType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => StepType.toolCall,
      ),
      config: json['config'] ?? {},
      nextSteps: List<String>.from(json['next_steps'] ?? []),
      condition: json['condition'],
    );
  }
}

class Workflow {
  final String id;
  final String name;
  final String description;
  final List<WorkflowStep> steps;
  final String startStepId;
  final DateTime createdAt;
  DateTime updatedAt;
  int executionCount;

  Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    required this.startStepId,
    required this.createdAt,
    required this.updatedAt,
    this.executionCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'steps': steps.map((s) => s.toJson()).toList(),
    'start_step_id': startStepId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'execution_count': executionCount,
  };

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      steps: (json['steps'] as List).map((s) => WorkflowStep.fromJson(s)).toList(),
      startStepId: json['start_step_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      executionCount: json['execution_count'] ?? 0,
    );
  }

  WorkflowStep? getStep(String id) {
    try {
      return steps.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

enum ExecutionStatus {
  pending,
  running,
  completed,
  failed,
  paused,
}

class WorkflowExecution {
  final String id;
  final String workflowId;
  final DateTime startedAt;
  DateTime? completedAt;
  ExecutionStatus status;
  final Map<String, dynamic> results;
  String? error;

  WorkflowExecution({
    required this.id,
    required this.workflowId,
    required this.startedAt,
    this.completedAt,
    this.status = ExecutionStatus.running,
    this.results = const {},
    this.error,
  });

  Duration get duration => (completedAt ?? DateTime.now()).difference(startedAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'workflow_id': workflowId,
    'started_at': startedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'status': status.name,
    'results': results,
    'error': error,
  };
}

class WorkflowEngine {
  final Map<String, Workflow> _workflows = {};
  final Map<String, WorkflowExecution> _executions = {};
  final StreamController<WorkflowExecution> _executionController =
      StreamController<WorkflowExecution>.broadcast();

  Stream<WorkflowExecution> get executionStream => _executionController.stream;

  String createWorkflow({
    required String name,
    required String description,
    required List<WorkflowStep> steps,
    required String startStepId,
  }) {
    final id = 'wf_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    _workflows[id] = Workflow(
      id: id,
      name: name,
      description: description,
      steps: steps,
      startStepId: startStepId,
      createdAt: now,
      updatedAt: now,
    );

    return id;
  }

  Workflow? getWorkflow(String id) => _workflows[id];

  List<Workflow> getAllWorkflows() => _workflows.values.toList();

  bool deleteWorkflow(String id) {
    return _workflows.remove(id) != null;
  }

  Future<WorkflowExecution> executeWorkflow(
    String workflowId, {
    required Future<dynamic> Function(String toolName, Map<String, dynamic> params) toolExecutor,
    Map<String, dynamic> initialContext = const {},
  }) async {
    final workflow = _workflows[workflowId];
    if (workflow == null) {
      throw Exception('Workflow not found: $workflowId');
    }

    final execution = WorkflowExecution(
      id: 'exec_${DateTime.now().millisecondsSinceEpoch}',
      workflowId: workflowId,
      startedAt: DateTime.now(),
    );

    _executions[execution.id] = execution;
    _executionController.add(execution);

    try {
      final context = Map<String, dynamic>.from(initialContext);
      await _executeStep(workflow, workflow.startStepId, context, toolExecutor);

      execution.status = ExecutionStatus.completed;
      execution.completedAt = DateTime.now();
      workflow.executionCount++;
      workflow.updatedAt = DateTime.now();
    } catch (e) {
      execution.status = ExecutionStatus.failed;
      execution.error = e.toString();
      execution.completedAt = DateTime.now();
    }

    _executionController.add(execution);
    return execution;
  }

  Future<void> _executeStep(
    Workflow workflow,
    String stepId,
    Map<String, dynamic> context,
    Future<dynamic> Function(String, Map<String, dynamic>) toolExecutor,
  ) async {
    final step = workflow.getStep(stepId);
    if (step == null) return;

    switch (step.type) {
      case StepType.toolCall:
        final toolName = step.config['tool'] as String? ?? '';
        final params = Map<String, dynamic>.from(step.config['params'] ?? {});
        
        for (final entry in params.entries) {
          if (entry.value is String && entry.value.toString().startsWith('\$(')) {
            final varName = entry.value.toString().replaceAll('\$(' , '').replaceAll(')', '');
            params[entry.key] = context[varName];
          }
        }

        final result = await toolExecutor(toolName, params);
        context[step.config['output'] ?? 'result'] = result;
        break;

      case StepType.condition:
        final condition = step.condition ?? 'true';
        final conditionResult = _evaluateCondition(condition, context);
        if (conditionResult && step.nextSteps.isNotEmpty) {
          await _executeStep(workflow, step.nextSteps[0], context, toolExecutor);
        } else if (!conditionResult && step.nextSteps.length > 1) {
          await _executeStep(workflow, step.nextSteps[1], context, toolExecutor);
        }
        return;

      case StepType.delay:
        final seconds = step.config['seconds'] as int? ?? 1;
        await Future.delayed(Duration(seconds: seconds));
        break;

      case StepType.transform:
        final expression = step.config['expression'] as String? ?? '';
        final output = step.config['output'] as String? ?? 'transformed';
        context[output] = _evaluateTransform(expression, context);
        break;

      case StepType.loop:
        final count = step.config['count'] as int? ?? 1;
        for (var i = 0; i < count; i++) {
          context['loop_index'] = i;
          for (final nextId in step.nextSteps) {
            await _executeStep(workflow, nextId, context, toolExecutor);
          }
        }
        break;

      case StepType.parallel:
        final futures = step.nextSteps.map((nextId) {
          return _executeStep(workflow, nextId, context, toolExecutor);
        });
        await Future.wait(futures);
        break;
    }

    for (final nextId in step.nextSteps) {
      if (step.type != StepType.condition && step.type != StepType.loop) {
        await _executeStep(workflow, nextId, context, toolExecutor);
      }
    }
  }

  bool _evaluateCondition(String condition, Map<String, dynamic> context) {
    try {
      var expr = condition;
      for (final entry in context.entries) {
        expr = expr.replaceAll('\$(${entry.key})', '${entry.value}');
      }
      return expr.toLowerCase() == 'true';
    } catch (e) {
      return false;
    }
  }

  dynamic _evaluateTransform(String expression, Map<String, dynamic> context) {
    try {
      var expr = expression;
      for (final entry in context.entries) {
        expr = expr.replaceAll('\$(${entry.key})', '${entry.value}');
      }
      return expr;
    } catch (e) {
      return expression;
    }
  }

  WorkflowExecution? getExecution(String id) => _executions[id];

  List<WorkflowExecution> getExecutionsForWorkflow(String workflowId) {
    return _executions.values.where((e) => e.workflowId == workflowId).toList();
  }

  void dispose() {
    _executionController.close();
  }
}
