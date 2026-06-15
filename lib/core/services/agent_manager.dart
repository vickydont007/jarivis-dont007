import 'dart:async';
import 'dart:ui';
import '../models/agent.dart' as agent_model;
import '../models/agent_task.dart';
import '../models/activity_event.dart';
import '../repositories/agent_repository.dart';
import '../repositories/task_repository.dart';
import '../agent_network.dart';
import '../dynamic_agent.dart' as dyn;
import 'timeline_service.dart';
import 'orb_state_manager.dart';

class AgentManager {
  final AgentRepository _agentRepository;
  final TaskRepository _taskRepository;
  final TimelineService _timeline;
  final OrbStateManager _orb;
  final StreamController<agent_model.Agent> _agentUpdateController =
      StreamController<agent_model.Agent>.broadcast();
  final StreamController<AgentTask> _taskUpdateController =
      StreamController<AgentTask>.broadcast();

  AgentManager({
    AgentRepository? agentRepository,
    TaskRepository? taskRepository,
    required TimelineService timeline,
    required OrbStateManager orb,
  })  : _agentRepository = agentRepository ?? InMemoryAgentRepository(),
        _taskRepository = taskRepository ?? InMemoryTaskRepository(),
        _timeline = timeline,
        _orb = orb;

  Stream<agent_model.Agent> get agentUpdates => _agentUpdateController.stream;
  Stream<AgentTask> get taskUpdates => _taskUpdateController.stream;

  Future<void> initializeDefaultAgents() async {
    final defaults = [
      agent_model.Agent.create(
        name: 'Research Agent',
        description: 'Analyzes information and finds insights',
        icon: '🔬',
      ),
      agent_model.Agent.create(
        name: 'Coding Agent',
        description: 'Writes and reviews code',
        icon: '💻',
      ),
      agent_model.Agent.create(
        name: 'Planner Agent',
        description: 'Manages schedules and tasks',
        icon: '📋',
      ),
      agent_model.Agent.create(
        name: 'Automation Agent',
        description: 'Handles automated workflows',
        icon: '⚡',
      ),
      agent_model.Agent.create(
        name: 'Monitor Agent',
        description: 'Watches system activity',
        icon: '🟢',
      ),
    ];
    await _agentRepository.saveAll(defaults);
  }

  Future<agent_model.Agent> registerAgent({
    required String name,
    required String description,
    required String icon,
  }) async {
    final agent = agent_model.Agent.create(
      name: name,
      description: description,
      icon: icon,
    );
    await _agentRepository.save(agent);
    await _timeline.log(
      source: 'AgentManager',
      type: ActivityType.agentStarted,
      title: 'Agent Registered',
      description: '$name agent registered',
      metadata: {'agentId': agent.id},
    );
    _agentUpdateController.add(agent);
    return agent;
  }

  Future<AgentTask> startTask({
    required String agentId,
    required String title,
    required String description,
  }) async {
    final agent = await _agentRepository.getById(agentId);
    if (agent == null) throw Exception('Agent not found: $agentId');

    final task = AgentTask.create(
      agentId: agentId,
      title: title,
      description: description,
    );

    final updatedAgent = agent.copyWith(
      status: agent_model.AgentStatus.working,
      currentTask: title,
      progress: 0.0,
      lastRun: DateTime.now(),
      totalTasks: agent.totalTasks + 1,
      updatedAt: DateTime.now(),
    );

    await _taskRepository.save(task);
    await _agentRepository.save(updatedAgent);

    _orb.requestThinking('agent:$agentId');
    await _timeline.log(
      source: agent.name,
      type: ActivityType.agentStarted,
      title: 'Task Started',
      description: title,
      metadata: {'agentId': agentId, 'taskId': task.id},
    );

    _agentUpdateController.add(updatedAgent);
    _taskUpdateController.add(task);
    return task;
  }

  Future<void> updateProgress({
    required String agentId,
    required String taskId,
    required double progress,
  }) async {
    final agent = await _agentRepository.getById(agentId);
    final task = await _taskRepository.getById(taskId);
    if (agent == null || task == null) return;

    final updatedTask = task.copyWith(
      progress: progress,
      status: AgentTaskStatus.inProgress,
      startedAt: task.startedAt ?? DateTime.now(),
    );

    final updatedAgent = agent.copyWith(
      progress: progress,
      updatedAt: DateTime.now(),
    );

    await _taskRepository.save(updatedTask);
    await _agentRepository.save(updatedAgent);

    _agentUpdateController.add(updatedAgent);
    _taskUpdateController.add(updatedTask);
  }

  Future<void> completeTask({
    required String agentId,
    required String taskId,
    String? result,
  }) async {
    final agent = await _agentRepository.getById(agentId);
    final task = await _taskRepository.getById(taskId);
    if (agent == null || task == null) return;

    final updatedTask = task.copyWith(
      progress: 1.0,
      status: AgentTaskStatus.completed,
      completedAt: DateTime.now(),
      result: result,
    );

    final updatedAgent = agent.copyWith(
      status: agent_model.AgentStatus.idle,
      currentTask: null,
      progress: 0.0,
      completedTasks: agent.completedTasks + 1,
      updatedAt: DateTime.now(),
    );

    await _taskRepository.save(updatedTask);
    await _agentRepository.save(updatedAgent);

    _orb.releaseThinking('agent:$agentId');
    await _timeline.log(
      source: agent.name,
      type: ActivityType.agentCompleted,
      title: 'Task Completed',
      description: task.title,
      metadata: {
        'agentId': agentId,
        'taskId': taskId,
        'duration': task.duration?.inSeconds,
      },
    );

    _agentUpdateController.add(updatedAgent);
    _taskUpdateController.add(updatedTask);
  }

  Future<void> failTask({
    required String agentId,
    required String taskId,
    String? error,
  }) async {
    final agent = await _agentRepository.getById(agentId);
    final task = await _taskRepository.getById(taskId);
    if (agent == null || task == null) return;

    final updatedTask = task.copyWith(
      status: AgentTaskStatus.failed,
      completedAt: DateTime.now(),
      error: error,
    );

    final updatedAgent = agent.copyWith(
      status: agent_model.AgentStatus.failed,
      failedTasks: agent.failedTasks + 1,
      updatedAt: DateTime.now(),
    );

    await _taskRepository.save(updatedTask);
    await _agentRepository.save(updatedAgent);

    _orb.releaseThinking('agent:$agentId');
    await _timeline.log(
      source: agent.name,
      type: ActivityType.agentFailed,
      title: 'Task Failed',
      description: '${task.title}: ${error ?? "Unknown error"}',
      metadata: {'agentId': agentId, 'taskId': taskId},
    );

    _agentUpdateController.add(updatedAgent);
    _taskUpdateController.add(updatedTask);
  }

  Future<List<agent_model.Agent>> getAllAgents() => _agentRepository.getAll();

  Future<agent_model.Agent?> getAgent(String id) => _agentRepository.getById(id);

  Future<List<AgentTask>> getAgentTasks(String agentId) =>
      _taskRepository.getByAgentId(agentId);

  Future<List<AgentTask>> getRecentTasks({int limit = 20}) =>
      _taskRepository.getRecent(limit: limit);

  Stream<List<agent_model.Agent>> watchAgents() => _agentRepository.watchAll();

  Stream<List<AgentTask>> watchTasks() => _taskRepository.watchAll();

  void dispose() {
    _agentUpdateController.close();
    _taskUpdateController.close();
  }
}

agent_model.AgentStatus _mapStatus(dyn.AgentStatus s) {
  switch (s) {
    case dyn.AgentStatus.spawning:
      return agent_model.AgentStatus.idle;
    case dyn.AgentStatus.idle:
      return agent_model.AgentStatus.idle;
    case dyn.AgentStatus.active:
      return agent_model.AgentStatus.working;
    case dyn.AgentStatus.busy:
      return agent_model.AgentStatus.working;
    case dyn.AgentStatus.failed:
      return agent_model.AgentStatus.failed;
    case dyn.AgentStatus.terminated:
      return agent_model.AgentStatus.idle;
  }
}

String _iconForRole(dyn.AgentRole role) {
  switch (role) {
    case dyn.AgentRole.orchestrator: return 'hub';
    case dyn.AgentRole.outreach: return 'send';
    case dyn.AgentRole.content: return 'palette';
    case dyn.AgentRole.dm: return 'chat';
    case dyn.AgentRole.comment: return 'comment';
    case dyn.AgentRole.lead: return 'target';
    case dyn.AgentRole.research: return 'search';
    case dyn.AgentRole.monitor: return 'eye';
    case dyn.AgentRole.code: return 'code';
    case dyn.AgentRole.scheduler: return 'schedule';
    case dyn.AgentRole.custom: return 'extension';
  }
}

class AgentRepositoryAdapter implements AgentRepository {
  final AgentNetwork _network;
  final _controller = StreamController<List<agent_model.Agent>>.broadcast();

  AgentRepositoryAdapter(this._network) {
    _network.eventStream.listen((_) => _notifyListeners());
    _notifyListeners();
  }

  agent_model.Agent _adapt(dyn.DynamicAgent a) => agent_model.Agent(
    id: a.id,
    name: a.name,
    description: a.description.isNotEmpty ? a.description : a.role.name,
    icon: _iconForRole(a.role),
    status: _mapStatus(a.status),
    currentTask: a.currentTask,
    progress: a.progress,
    createdAt: a.spawnTime,
    updatedAt: a.lastActive ?? a.spawnTime,
    lastRun: a.lastActive,
    totalTasks: a.tasksCompleted + a.tasksFailed,
    completedTasks: a.tasksCompleted,
    failedTasks: a.tasksFailed,
  );

  @override
  Future<void> save(agent_model.Agent agent) async {}

  @override
  Future<void> saveAll(List<agent_model.Agent> agents) async {}

  @override
  Future<agent_model.Agent?> getById(String id) async {
    final da = _network.getAgentById(id);
    return da != null ? _adapt(da) : null;
  }

  @override
  Future<List<agent_model.Agent>> getAll() async {
    return _network.agents.where((a) => a.isAlive).map(_adapt).toList();
  }

  @override
  Future<List<agent_model.Agent>> getByStatus(agent_model.AgentStatus status) async {
    final all = await getAll();
    return all.where((a) => a.status == status).toList();
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<List<agent_model.Agent>> watchAll() => _controller.stream;

  void _notifyListeners() {
    final agents = _network.agents.where((a) => a.isAlive).map(_adapt).toList();
    _controller.add(agents);
  }

  void dispose() {
    _controller.close();
  }
}

class TaskRepositoryEmpty implements TaskRepository {
  @override
  Future<void> save(AgentTask task) async {}
  @override
  Future<AgentTask?> getById(String id) async => null;
  @override
  Future<List<AgentTask>> getAll() async => [];
  @override
  Future<List<AgentTask>> getByAgentId(String agentId) async => [];
  @override
  Future<List<AgentTask>> getByStatus(AgentTaskStatus status) async => [];
  @override
  Future<List<AgentTask>> getRecent({int limit = 50}) async => [];
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> clear() async {}
  @override
  Stream<List<AgentTask>> watchAll() => const Stream.empty();
}
