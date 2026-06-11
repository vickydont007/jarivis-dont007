import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';

enum AgentType {
  morningDigest,
  deepResearch,
  monitorOperative,
  orchestrator,
  nativeReact,
  operative,
  codeAssistant,
  simple,
}

enum AgentStatus {
  idle,
  running,
  completed,
  failed,
  paused,
}

class AgentTask {
  final String id;
  final String agentId;
  final String description;
  final Map<String, dynamic> parameters;
  final AgentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? result;
  final String? error;

  AgentTask({
    required this.id,
    required this.agentId,
    required this.description,
    this.parameters = const {},
    this.status = AgentStatus.idle,
    required this.createdAt,
    this.completedAt,
    this.result,
    this.error,
  });

  factory AgentTask.create({
    required String agentId,
    required String description,
    Map<String, dynamic> parameters = const {},
  }) {
    return AgentTask(
      id: const Uuid().v4(),
      agentId: agentId,
      description: description,
      parameters: parameters,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agent_id': agentId,
      'description': description,
      'parameters': parameters,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'result': result,
      'error': error,
    };
  }
}

class Agent {
  final String id;
  final String name;
  final String description;
  final AgentType type;
  final List<String> capabilities;
  final bool isActive;
  final int maxConcurrentTasks;

  Agent({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.capabilities = const [],
    this.isActive = true,
    this.maxConcurrentTasks = 1,
  });

  factory Agent.create({
    required String name,
    required String description,
    required AgentType type,
    List<String> capabilities = const [],
  }) {
    return Agent(
      id: const Uuid().v4(),
      name: name,
      description: description,
      type: type,
      capabilities: capabilities,
    );
  }
}

class AgentOrchestrator {
  final List<Agent> _agents = [];
  final List<AgentTask> _tasks = [];
  final StreamController<AgentTask> _taskController =
      StreamController<AgentTask>.broadcast();

  Stream<AgentTask> get taskStream => _taskController.stream;
  List<Agent> get agents => List.unmodifiable(_agents);
  List<AgentTask> get tasks => List.unmodifiable(_tasks);

  AgentOrchestrator() {
    _initializeDefaultAgents();
  }

  void _initializeDefaultAgents() {
    // 1. Morning Digest Agent
    _agents.add(Agent.create(
      name: 'Morning Digest',
      description: 'Daily briefing from email, calendar, health, news',
      type: AgentType.morningDigest,
      capabilities: ['email', 'calendar', 'news', 'weather', 'tts'],
    ));

    // 2. Deep Research Agent
    _agents.add(Agent.create(
      name: 'Deep Research',
      description: 'Multi-hop research across indexed docs with citations',
      type: AgentType.deepResearch,
      capabilities: ['web_search', 'document_analysis', 'citations'],
    ));

    // 3. Monitor Operative
    _agents.add(Agent.create(
      name: 'Monitor Operative',
      description: 'Long-horizon monitoring with memory and retrieval',
      type: AgentType.monitorOperative,
      capabilities: ['monitoring', 'alerts', 'memory'],
    ));

    // 4. Orchestrator
    _agents.add(Agent.create(
      name: 'Orchestrator',
      description: 'Multi-turn reasoning with automatic tool selection',
      type: AgentType.orchestrator,
      capabilities: ['reasoning', 'tool_selection', 'multi_turn'],
    ));

    // 5. Native React
    _agents.add(Agent.create(
      name: 'Native React',
      description: 'ReAct (Thought-Action-Observation) loop agent',
      type: AgentType.nativeReact,
      capabilities: ['react_loop', 'tool_use', 'observation'],
    ));

    // 6. Operative
    _agents.add(Agent.create(
      name: 'Operative',
      description: 'Persistent autonomous agent with state management',
      type: AgentType.operative,
      capabilities: ['autonomous', 'state_management', 'persistence'],
    ));

    // 7. Code Assistant
    _agents.add(Agent.create(
      name: 'Code Assistant',
      description: 'Agent with code execution, file I/O, and shell access',
      type: AgentType.codeAssistant,
      capabilities: ['code_execution', 'file_io', 'shell', 'git'],
    ));

    // 8. Simple
    _agents.add(Agent.create(
      name: 'Simple',
      description: 'Lightweight conversation, no tools',
      type: AgentType.simple,
      capabilities: ['chat', 'basic_qa'],
    ));
  }

  // Get agent by type
  Agent? getAgentByType(AgentType type) {
    try {
      return _agents.firstWhere((a) => a.type == type);
    } catch (e) {
      return null;
    }
  }

  // Create task
  Future<AgentTask> createTask({
    required String agentId,
    required String description,
    Map<String, dynamic> parameters = const {},
  }) async {
    final task = AgentTask.create(
      agentId: agentId,
      description: description,
      parameters: parameters,
    );

    _tasks.add(task);
    _taskController.add(task);

    return task;
  }

  // Execute task
  Future<String> executeTask(AgentTask task) async {
    final agent = _agents.firstWhere(
      (a) => a.id == task.agentId,
      orElse: () => throw Exception('Agent not found'),
    );

    if (!agent.isActive) {
      throw Exception('Agent is not active');
    }

    // Update task status
    final updatedTask = AgentTask(
      id: task.id,
      agentId: task.agentId,
      description: task.description,
      parameters: task.parameters,
      status: AgentStatus.running,
      createdAt: task.createdAt,
    );

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      _taskController.add(updatedTask);
    }

    try {
      // Execute based on agent type
      final result = await _executeAgentLogic(agent, task);

      // Update task with result
      final completedTask = AgentTask(
        id: task.id,
        agentId: task.agentId,
        description: task.description,
        parameters: task.parameters,
        status: AgentStatus.completed,
        createdAt: task.createdAt,
        completedAt: DateTime.now(),
        result: result,
      );

      final completedIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (completedIndex != -1) {
        _tasks[completedIndex] = completedTask;
        _taskController.add(completedTask);
      }

      return result;
    } catch (e) {
      // Update task with error
      final failedTask = AgentTask(
        id: task.id,
        agentId: task.agentId,
        description: task.description,
        parameters: task.parameters,
        status: AgentStatus.failed,
        createdAt: task.createdAt,
        completedAt: DateTime.now(),
        error: e.toString(),
      );

      final failedIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (failedIndex != -1) {
        _tasks[failedIndex] = failedTask;
        _taskController.add(failedTask);
      }

      rethrow;
    }
  }

  Future<String> _executeAgentLogic(Agent agent, AgentTask task) async {
    switch (agent.type) {
      case AgentType.morningDigest:
        return await _executeMorningDigest(task);
      case AgentType.deepResearch:
        return await _executeDeepResearch(task);
      case AgentType.monitorOperative:
        return await _executeMonitorOperative(task);
      case AgentType.orchestrator:
        return await _executeOrchestrator(task);
      case AgentType.nativeReact:
        return await _executeNativeReact(task);
      case AgentType.operative:
        return await _executeOperative(task);
      case AgentType.codeAssistant:
        return await _executeCodeAssistant(task);
      case AgentType.simple:
        return await _executeSimple(task);
    }
  }

  Future<String> _executeMorningDigest(AgentTask task) async {
    // TODO: Implement morning digest
    return 'Morning Digest: Good morning! Here is your daily briefing.';
  }

  Future<String> _executeDeepResearch(AgentTask task) async {
    // TODO: Implement deep research
    return 'Deep Research: Analysis complete for "${task.description}".';
  }

  Future<String> _executeMonitorOperative(AgentTask task) async {
    // TODO: Implement monitoring
    return 'Monitor: Active monitoring started for "${task.description}".';
  }

  Future<String> _executeOrchestrator(AgentTask task) async {
    // TODO: Implement orchestrator
    return 'Orchestrator: Task planned and delegated for "${task.description}".';
  }

  Future<String> _executeNativeReact(AgentTask task) async {
    // TODO: Implement ReAct loop
    return 'React Agent: Thought-Action-Observation cycle completed.';
  }

  Future<String> _executeOperative(AgentTask task) async {
    // TODO: Implement operative
    return 'Operative: Autonomous task execution for "${task.description}".';
  }

  Future<String> _executeCodeAssistant(AgentTask task) async {
    // TODO: Implement code assistant
    return 'Code Assistant: Code analysis complete for "${task.description}".';
  }

  Future<String> _executeSimple(AgentTask task) async {
    // TODO: Implement simple chat
    return 'Simple Agent: I received your message "${task.description}".';
  }

  // Delegate to sub-agent
  Future<String> delegateToSubAgent({
    required String parentAgentId,
    required String subAgentType,
    required String taskDescription,
  }) async {
    // TODO: Implement sub-agent delegation
    return 'Sub-agent ($subAgentType) completed: $taskDescription';
  }

  // Get tasks by status
  List<AgentTask> getTasksByStatus(AgentStatus status) {
    return _tasks.where((t) => t.status == status).toList();
  }

  // Get tasks by agent
  List<AgentTask> getTasksByAgent(String agentId) {
    return _tasks.where((t) => t.agentId == agentId).toList();
  }

  void dispose() {
    _taskController.close();
  }
}
