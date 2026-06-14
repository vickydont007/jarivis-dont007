import 'dart:async';
import '../models/agent.dart';
import '../models/agent_task.dart';
import '../models/activity_event.dart';
import '../repositories/agent_repository.dart';
import '../repositories/task_repository.dart';
import 'timeline_service.dart';
import 'orb_state_manager.dart';

class AgentManager {
  final AgentRepository _agentRepository;
  final TaskRepository _taskRepository;
  final TimelineService _timeline;
  final OrbStateManager _orb;
  final StreamController<Agent> _agentUpdateController =
      StreamController<Agent>.broadcast();
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

  Stream<Agent> get agentUpdates => _agentUpdateController.stream;
  Stream<AgentTask> get taskUpdates => _taskUpdateController.stream;

  Future<void> initializeDefaultAgents() async {
    final defaults = [
      Agent.create(
        name: 'Research Agent',
        description: 'Analyzes information and finds insights',
        icon: '🔬',
      ),
      Agent.create(
        name: 'Coding Agent',
        description: 'Writes and reviews code',
        icon: '💻',
      ),
      Agent.create(
        name: 'Planner Agent',
        description: 'Manages schedules and tasks',
        icon: '📋',
      ),
      Agent.create(
        name: 'Automation Agent',
        description: 'Handles automated workflows',
        icon: '⚡',
      ),
      Agent.create(
        name: 'Monitor Agent',
        description: 'Watches system activity',
        icon: '🟢',
      ),
    ];
    await _agentRepository.saveAll(defaults);
  }

  Future<Agent> registerAgent({
    required String name,
    required String description,
    required String icon,
  }) async {
    final agent = Agent.create(
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
      status: AgentStatus.working,
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
      status: AgentStatus.idle,
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
      status: AgentStatus.failed,
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

  Future<List<Agent>> getAllAgents() => _agentRepository.getAll();

  Future<Agent?> getAgent(String id) => _agentRepository.getById(id);

  Future<List<AgentTask>> getAgentTasks(String agentId) =>
      _taskRepository.getByAgentId(agentId);

  Future<List<AgentTask>> getRecentTasks({int limit = 20}) =>
      _taskRepository.getRecent(limit: limit);

  Stream<List<Agent>> watchAgents() => _agentRepository.watchAll();

  Stream<List<AgentTask>> watchTasks() => _taskRepository.watchAll();

  void dispose() {
    _agentUpdateController.close();
    _taskUpdateController.close();
  }
}
