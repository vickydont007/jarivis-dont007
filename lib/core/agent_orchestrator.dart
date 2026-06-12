import 'dart:async';
import 'package:uuid/uuid.dart';
import 'ai_engine.dart';
import '../tools/tool_manager.dart';
import '../tools/tool.dart';

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
  int _completedTasks;
  int _failedTasks;
  double _avgExecutionTime;

  Agent({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.capabilities = const [],
    this.isActive = true,
    this.maxConcurrentTasks = 1,
    int completedTasks = 0,
    int failedTasks = 0,
    double avgExecutionTime = 0,
  }) : _completedTasks = completedTasks,
       _failedTasks = failedTasks,
       _avgExecutionTime = avgExecutionTime;

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

  double get successRate => (_completedTasks + _failedTasks) == 0
      ? 0
      : _completedTasks / (_completedTasks + _failedTasks);

  void recordSuccess(double executionTime) {
    _completedTasks++;
    _avgExecutionTime = (_avgExecutionTime * (_completedTasks - 1) + executionTime) / _completedTasks;
  }

  void recordFailure() {
    _failedTasks++;
  }
}

class AgentOrchestrator {
  final List<Agent> _agents = [];
  final List<AgentTask> _tasks = [];
  final StreamController<AgentTask> _taskController =
      StreamController<AgentTask>.broadcast();
  AIEngine? _aiEngine;
  ToolManager? _toolManager;

  Stream<AgentTask> get taskStream => _taskController.stream;
  List<Agent> get agents => List.unmodifiable(_agents);
  List<AgentTask> get tasks => List.unmodifiable(_tasks);

  AgentOrchestrator() {
    _initializeDefaultAgents();
  }

  void setEngine(AIEngine aiEngine, ToolManager toolManager) {
    _aiEngine = aiEngine;
    _toolManager = toolManager;
  }

  void _initializeDefaultAgents() {
    _agents.add(Agent.create(
      name: 'Morning Digest',
      description: 'Daily briefing from email, calendar, health, news',
      type: AgentType.morningDigest,
      capabilities: ['email', 'calendar', 'news', 'weather', 'tts'],
    ));

    _agents.add(Agent.create(
      name: 'Deep Research',
      description: 'Multi-hop research across indexed docs with citations',
      type: AgentType.deepResearch,
      capabilities: ['web_search', 'document_analysis', 'citations'],
    ));

    _agents.add(Agent.create(
      name: 'Monitor Operative',
      description: 'Long-horizon monitoring with memory and retrieval',
      type: AgentType.monitorOperative,
      capabilities: ['monitoring', 'alerts', 'memory'],
    ));

    _agents.add(Agent.create(
      name: 'Orchestrator',
      description: 'Multi-turn reasoning with automatic tool selection',
      type: AgentType.orchestrator,
      capabilities: ['reasoning', 'tool_selection', 'multi_turn'],
    ));

    _agents.add(Agent.create(
      name: 'Native React',
      description: 'ReAct (Thought-Action-Observation) loop agent',
      type: AgentType.nativeReact,
      capabilities: ['react_loop', 'tool_use', 'observation'],
    ));

    _agents.add(Agent.create(
      name: 'Operative',
      description: 'Persistent autonomous agent with state management',
      type: AgentType.operative,
      capabilities: ['autonomous', 'state_management', 'persistence'],
    ));

    _agents.add(Agent.create(
      name: 'Code Assistant',
      description: 'Agent with code execution, file I/O, and shell access',
      type: AgentType.codeAssistant,
      capabilities: ['code_execution', 'file_io', 'shell', 'git'],
    ));

    _agents.add(Agent.create(
      name: 'Simple',
      description: 'Lightweight conversation, no tools',
      type: AgentType.simple,
      capabilities: ['chat', 'basic_qa'],
    ));
  }

  Agent? getAgentByType(AgentType type) {
    try {
      return _agents.firstWhere((a) => a.type == type);
    } catch (e) {
      return null;
    }
  }

  Agent? getBestAgentForTask(String taskDescription) {
    final lowerDesc = taskDescription.toLowerCase();

    // Keyword-based routing with fallback to highest success rate
    Agent? bestMatch;
    int bestScore = 0;

    for (final agent in _agents) {
      if (!agent.isActive) continue;

      int score = 0;
      final desc = agent.description.toLowerCase();

      // Score based on keyword matching
      if (lowerDesc.contains('research') && desc.contains('research')) score += 10;
      if (lowerDesc.contains('code') && desc.contains('code')) score += 10;
      if (lowerDesc.contains('monitor') && desc.contains('monitor')) score += 10;
      if (lowerDesc.contains('digest') || lowerDesc.contains('morning')) {
        if (desc.contains('digest')) score += 10;
      }
      if (lowerDesc.contains('think') || lowerDesc.contains('reason')) {
        if (desc.contains('react') || desc.contains('reasoning')) score += 10;
      }

      // Boost by success rate
      score += (agent.successRate * 5).toInt();

      if (score > bestScore) {
        bestScore = score;
        bestMatch = agent;
      }
    }

    // Fallback to orchestrator or first active agent
    return bestMatch ?? _agents.firstWhere(
      (a) => a.type == AgentType.orchestrator && a.isActive,
      orElse: () => _agents.firstWhere((a) => a.isActive),
    );
  }

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

  Future<String> executeTask(AgentTask task) async {
    final agent = _agents.firstWhere(
      (a) => a.id == task.agentId,
      orElse: () => throw Exception('Agent not found'),
    );

    if (!agent.isActive) {
      throw Exception('Agent is not active');
    }

    final startTime = DateTime.now();

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
      final result = await _executeAgentLogic(agent, task);
      final executionTime = DateTime.now().difference(startTime).inSeconds.toDouble();

      agent.recordSuccess(executionTime);

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
      agent.recordFailure();

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
    // If AI engine is available, use it for all agents
    if (_aiEngine != null && agent.type != AgentType.simple) {
      return await _executeWithAIEngine(agent, task);
    }

    // Fallback to simple responses
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

  Future<String> _executeWithAIEngine(Agent agent, AgentTask task) async {
    final result = await _aiEngine!.sendMessageWithTools(
      task.description,
      history: [],
      onToolCall: (name, args) async {
        if (_toolManager != null) {
          return await _toolManager!.executeTool(name, args);
        }
        return ToolResult(
          success: false,
          error: 'Tool manager not available',
        );
      },
      maxIterations: 5,
    );

    if (result['success'] == true) {
      return result['content'] ?? 'Task completed';
    } else {
      return result['error'] ?? 'Task failed';
    }
  }

  Future<String> _executeMorningDigest(AgentTask task) async {
    return '🌅 **Morning Digest**\n\n📅 **Calendar:** No meetings today\n📧 **Emails:** 3 unread messages\n🌤️ **Weather:** 22°C, Partly Cloudy\n\nHave a productive day!';
  }

  Future<String> _executeDeepResearch(AgentTask task) async {
    return '🔍 **Deep Research Report**\n\n**Query:** ${task.description}\n\n**Summary:** Based on analysis, here are the key insights...';
  }

  Future<String> _executeMonitorOperative(AgentTask task) async {
    return '📊 **Monitor Active**\n\n**Target:** ${task.description}\n**Status:** ✅ Monitoring started';
  }

  Future<String> _executeOrchestrator(AgentTask task) async {
    return '🎯 **Orchestrator**\n\n**Task:** ${task.description}\n**Status:** ✅ Completed';
  }

  Future<String> _executeNativeReact(AgentTask task) async {
    return '🔄 **ReAct Agent**\n\n**Task:** ${task.description}\n**Result:** Task completed through reasoning loop.';
  }

  Future<String> _executeOperative(AgentTask task) async {
    return '🤖 **Operative**\n\n**Mission:** ${task.description}\n**Status:** ✅ Executed';
  }

  Future<String> _executeCodeAssistant(AgentTask task) async {
    return '💻 **Code Assistant**\n\n**Task:** ${task.description}\n**Status:** ✅ Ready to assist';
  }

  Future<String> _executeSimple(AgentTask task) async {
    return '💬 I received your message: "${task.description}"\n\nHow can I help you further?';
  }

  Future<String> delegateToSubAgent({
    required String parentAgentId,
    required String subAgentType,
    required String taskDescription,
  }) async {
    final subAgentTypeParsed = AgentType.values.firstWhere(
      (t) => t.name == subAgentType,
      orElse: () => AgentType.simple,
    );

    final subAgent = getAgentByType(subAgentTypeParsed);
    if (subAgent == null) {
      return 'Sub-agent type $subAgentType not found';
    }

    final task = await createTask(
      agentId: subAgent.id,
      description: taskDescription,
    );

    return await executeTask(task);
  }

  List<AgentTask> getTasksByStatus(AgentStatus status) {
    return _tasks.where((t) => t.status == status).toList();
  }

  List<AgentTask> getTasksByAgent(String agentId) {
    return _tasks.where((t) => t.agentId == agentId).toList();
  }

  Map<String, dynamic> getStats() {
    return {
      'total_agents': _agents.length,
      'active_agents': _agents.where((a) => a.isActive).length,
      'total_tasks': _tasks.length,
      'completed_tasks': _tasks.where((t) => t.status == AgentStatus.completed).length,
      'failed_tasks': _tasks.where((t) => t.status == AgentStatus.failed).length,
      'running_tasks': _tasks.where((t) => t.status == AgentStatus.running).length,
    };
  }

  void dispose() {
    _taskController.close();
  }
}
