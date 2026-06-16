import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/workflow.dart';
import '../agents/agent_registry.dart';
import '../services/goal_planner.dart';
import '../services/agent_message_bus.dart';
import '../workflows/workflow_engine.dart';
import '../workflows/workflow_database.dart';
import '../ai_engine.dart';
import '../../tools/tool_manager.dart';

class OrchestratorEvent {
  final String type;
  final String workflowId;
  final dynamic data;
  final DateTime timestamp;

  OrchestratorEvent({
    required this.type,
    required this.workflowId,
    this.data,
    required this.timestamp,
  });
}

class MultiAgentOrchestrator {
  static const _uuid = Uuid();

  final ToolManager _toolManager;
  final AgentRegistry _registry;
  late final GoalPlanner _planner;
  late final WorkflowEngine _engine;
  final AgentMessageBus _messageBus;
  final WorkflowDatabase _db;
  final AIEngine? Function() _getEngine;

  final StreamController<OrchestratorEvent> _eventController =
      StreamController<OrchestratorEvent>.broadcast();

  final Map<String, Workflow> _activeWorkflows = {};

  MultiAgentOrchestrator({
    required ToolManager toolManager,
    required AIEngine? Function() getEngine,
    AgentRegistry? registry,
    AgentMessageBus? messageBus,
    WorkflowDatabase? db,
  })  : _toolManager = toolManager,
        _getEngine = getEngine,
        _registry = registry ?? AgentRegistry(),
        _messageBus = messageBus ?? AgentMessageBus(),
        _db = db ?? WorkflowDatabase() {
    _engine = WorkflowEngine(
      toolManager: _toolManager,
      messageBus: _messageBus,
      db: _db,
    );
    _planner = GoalPlanner(
      getEngine: _getEngine,
      registry: _registry,
    );
  }

  ToolManager get toolManager => _toolManager;
  AgentRegistry get registry => _registry;
  GoalPlanner get planner => _planner;
  WorkflowEngine get engine => _engine;
  AgentMessageBus get messageBus => _messageBus;
  WorkflowDatabase get database => _db;
  Stream<OrchestratorEvent> get eventStream => _eventController.stream;

  void initialize() {
    _messageBus.messageStream.listen((msg) {
      _eventController.add(OrchestratorEvent(
        type: msg.type.name,
        workflowId: msg.workflowId,
        data: msg.data,
        timestamp: msg.timestamp,
      ));
    });
  }

  Future<WorkflowResult> executeGoal(String goal, {Map<String, dynamic>? context}) async {
    final plan = await _planner.planGoal(goal);

    final workflow = Workflow(
      id: _uuid.v4(),
      goal: goal,
      description: plan.summary,
      tasks: plan.tasks,
      context: context ?? {},
      createdAt: DateTime.now(),
    );

    _activeWorkflows[workflow.id] = workflow;

    _eventController.add(OrchestratorEvent(
      type: 'goal_planned',
      workflowId: workflow.id,
      data: {
        'goal': goal,
        'taskCount': plan.tasks.length,
        'summary': plan.summary,
      },
      timestamp: DateTime.now(),
    ));

    final result = await _engine.execute(workflow);

    _activeWorkflows.remove(workflow.id);

    return result;
  }

  Future<WorkflowResult?> getWorkflowResult(String workflowId) async {
    return _engine.getResult(workflowId);
  }

  void cancelWorkflow(String workflowId) {
    _engine.cancelWorkflow(workflowId);
    _activeWorkflows.remove(workflowId);
    _eventController.add(OrchestratorEvent(
      type: 'workflow_cancelled',
      workflowId: workflowId,
      timestamp: DateTime.now(),
    ));
  }

  Future<List<Workflow>> getActiveWorkflows() async {
    return _db.getWorkflows(status: WorkflowStatus.running);
  }

  Future<List<Workflow>> getRecentWorkflows({int limit = 20}) async {
    return _db.getWorkflows(limit: limit);
  }

  Future<List<Workflow>> getWorkflowsByStatus(WorkflowStatus status) async {
    return _db.getWorkflows(status: status);
  }

  Future<List<Map<String, dynamic>>> getWorkflowMessages(String workflowId) async {
    return _db.getMessages(workflowId);
  }

  List<RegisteredAgent> getAvailableAgents() => _registry.agents;

  RegisteredAgent? getAgent(String type) => _registry.findByType(type);

  Map<String, String> getToolAgentMap() => _registry.toolToAgentMap;

  String getToolsPrompt() {
    final agents = _registry.agents;
    final buffer = StringBuffer('MULTI-AGENT ORCHESTRATOR:\n');
    buffer.writeln('You have access to a multi-agent system. When the user gives a high-level goal, you can orchestrate multiple agents to complete it.\n');
    buffer.writeln('AVAILABLE AGENTS:');
    for (final agent in agents) {
      buffer.writeln('- ${agent.icon} ${agent.name} (${agent.type}): ${agent.description}');
      for (final cap in agent.capabilities) {
        buffer.writeln('    Capabilities: ${cap.name} - ${cap.toolNames.join(", ")}');
      }
    }
    buffer.writeln('\nTo execute a multi-step workflow, use the orchestrator_create_workflow tool with a goal description.');
    buffer.writeln('The orchestrator will decompose the goal, select agents, and execute the workflow automatically.');
    return buffer.toString();
  }

  void dispose() {
    _eventController.close();
    _messageBus.dispose();
  }
}
