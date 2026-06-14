import 'dart:async';
import 'dart:convert';
import '../models/activity_event.dart';
import '../models/agent.dart';
import '../models/agent_task.dart';
import 'agent_manager.dart';
import 'timeline_service.dart';
import 'orb_state_manager.dart';
import 'agent_executor.dart';

enum CollaborationStatus { idle, planning, executing, reporting, completed, failed }

enum AgentRole { planner, researcher, coder, reporter }

class AgentStep {
  final String agentName;
  final AgentRole role;
  final String task;
  String? result;
  final DateTime startedAt;
  DateTime? completedAt;
  bool get isDone => completedAt != null;

  AgentStep({
    required this.agentName,
    required this.role,
    required this.task,
    this.result,
    required this.startedAt,
    this.completedAt,
  });
}

class CollaborationResult {
  final String id;
  final String userRequest;
  CollaborationStatus status;
  final List<AgentStep> steps;
  String? finalReport;
  final DateTime startedAt;
  DateTime? completedAt;

  CollaborationResult({
    required this.id,
    required this.userRequest,
    required this.status,
    required this.steps,
    this.finalReport,
    required this.startedAt,
    this.completedAt,
  });

  Duration? get duration => completedAt?.difference(startedAt);
}

class AgentCollaboration {
  final AgentManager _agentManager;
  final TimelineService _timeline;
  final OrbStateManager _orb;
  AgentExecutor? _executor;

  final StreamController<CollaborationResult> _resultController =
      StreamController<CollaborationResult>.broadcast();
  final StreamController<AgentStep> _stepController =
      StreamController<AgentStep>.broadcast();

  Stream<CollaborationResult> get resultStream => _resultController.stream;
  Stream<AgentStep> get stepStream => _stepController.stream;

  AgentCollaboration({
    required AgentManager agentManager,
    required TimelineService timeline,
    required OrbStateManager orb,
    AgentExecutor? executor,
  })  : _agentManager = agentManager,
        _timeline = timeline,
        _orb = orb,
        _executor = executor;

  void setExecutor(AgentExecutor executor) {
    _executor = executor;
  }

  Future<CollaborationResult> execute(String userRequest) async {
    final result = CollaborationResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userRequest: userRequest,
      status: CollaborationStatus.planning,
      steps: [],
      startedAt: DateTime.now(),
    );

    _resultController.add(result);

    try {
      final plan = await _planTasks(userRequest, result);

      result.status = CollaborationStatus.executing;
      _resultController.add(result);

      await _executePlan(plan, result);

      result.status = CollaborationStatus.reporting;
      _resultController.add(result);

      final report = await _generateReport(result);

      result.finalReport = report;
      result.status = CollaborationStatus.completed;
      result.completedAt = DateTime.now();

      await _timeline.log(
        source: 'Collaboration',
        type: ActivityType.agentCompleted,
        title: 'Collaboration Completed',
        description: 'Multi-agent task completed: ${userRequest.length > 50 ? userRequest.substring(0, 50) : userRequest}',
        metadata: {
          'steps': result.steps.length,
          'duration': result.duration?.inSeconds,
        },
      );

      _resultController.add(result);
      return result;
    } catch (e) {
      result.status = CollaborationStatus.failed;
      result.completedAt = DateTime.now();

      await _timeline.log(
        source: 'Collaboration',
        type: ActivityType.agentFailed,
        title: 'Collaboration Failed',
        description: 'Error: $e',
      );

      _resultController.add(result);
      return result;
    }
  }

  Future<List<_PlannedStep>> _planTasks(String userRequest, CollaborationResult result) async {
    final steps = <_PlannedStep>[];

    steps.add(_PlannedStep(
      agentName: 'Research Agent',
      role: AgentRole.researcher,
      task: 'Research and gather information for: $userRequest',
    ));

    steps.add(_PlannedStep(
      agentName: 'Coding Agent',
      role: AgentRole.coder,
      task: 'Implement the solution based on research findings',
    ));

    steps.add(_PlannedStep(
      agentName: 'Research Agent',
      role: AgentRole.researcher,
      task: 'Validate the implementation and verify results',
    ));

    steps.add(_PlannedStep(
      agentName: 'Planner Agent',
      role: AgentRole.reporter,
      task: 'Summarize all findings and generate a final report',
    ));

    return steps;
  }

  Future<void> _executePlan(List<_PlannedStep> plan, CollaborationResult result) async {
    for (final plannedStep in plan) {
      final step = AgentStep(
        agentName: plannedStep.agentName,
        role: plannedStep.role,
        task: plannedStep.task,
        startedAt: DateTime.now(),
      );

      result.steps.add(step);
      _stepController.add(step);

      try {
        final agent = await _findOrCreateAgent(plannedStep.agentName);

        if (_executor != null) {
          final taskResult = await _executor!.execute(
            task: plannedStep.task,
            agentName: plannedStep.agentName,
          );
          step.result = taskResult.response;
        } else {
          step.result = 'Agent ${plannedStep.agentName} completed: ${plannedStep.task}';
        }

        step.completedAt = DateTime.now();
        _stepController.add(step);

        await _timeline.log(
          source: plannedStep.agentName,
          type: ActivityType.agentCompleted,
          title: 'Collaboration Step',
          description: plannedStep.task,
          metadata: {'step': result.steps.length},
        );
      } catch (e) {
        step.result = 'Error: $e';
        step.completedAt = DateTime.now();
        _stepController.add(step);

        await _timeline.log(
          source: plannedStep.agentName,
          type: ActivityType.agentFailed,
          title: 'Step Failed',
          description: '$e',
        );
      }
    }
  }

  Future<Agent> _findOrCreateAgent(String name) async {
    final agents = await _agentManager.getAllAgents();
    final existing = agents.where((a) => a.name == name).toList();
    if (existing.isNotEmpty) return existing.first;

    return await _agentManager.registerAgent(
      name: name,
      description: 'Auto-created for collaboration',
      icon: '🤖',
    );
  }

  Future<String> _generateReport(CollaborationResult result) async {
    final completedSteps = result.steps.where((s) => s.isDone).length;
    final failedSteps = result.steps.where((s) => s.result?.startsWith('Error') == true).length;
    final duration = result.duration?.inSeconds ?? 0;

    final buffer = StringBuffer();
    buffer.writeln('Collaboration Report');
    buffer.writeln('Request: ${result.userRequest}');
    buffer.writeln('Status: ${result.status.name}');
    buffer.writeln('Steps: $completedSteps completed, $failedSteps failed');
    buffer.writeln('Duration: ${duration}s');
    buffer.writeln();
    buffer.writeln('Step Results:');

    for (var i = 0; i < result.steps.length; i++) {
      final step = result.steps[i];
      buffer.writeln('${i + 1}. [${step.agentName}] ${step.task}');
      buffer.writeln('   Result: ${step.result ?? "pending"}');
    }

    return buffer.toString();
  }

  void dispose() {
    _resultController.close();
    _stepController.close();
  }
}

class _PlannedStep {
  final String agentName;
  final AgentRole role;
  final String task;

  _PlannedStep({
    required this.agentName,
    required this.role,
    required this.task,
  });
}
