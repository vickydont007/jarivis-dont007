import 'dart:async';
import '../models/agent_task.dart';

abstract class TaskRepository {
  Future<void> save(AgentTask task);
  Future<AgentTask?> getById(String id);
  Future<List<AgentTask>> getAll();
  Future<List<AgentTask>> getByAgentId(String agentId);
  Future<List<AgentTask>> getByStatus(AgentTaskStatus status);
  Future<List<AgentTask>> getRecent({int limit = 50});
  Future<void> delete(String id);
  Future<void> clear();
  Stream<List<AgentTask>> watchAll();
}

class InMemoryTaskRepository implements TaskRepository {
  final Map<String, AgentTask> _tasks = {};
  final StreamController<List<AgentTask>> _controller =
      StreamController<List<AgentTask>>.broadcast();

  @override
  Future<void> save(AgentTask task) async {
    _tasks[task.id] = task;
    _notifyListeners();
  }

  @override
  Future<AgentTask?> getById(String id) async => _tasks[id];

  @override
  Future<List<AgentTask>> getAll() async =>
      _tasks.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<AgentTask>> getByAgentId(String agentId) async {
    return _tasks.values
        .where((t) => t.agentId == agentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<AgentTask>> getByStatus(AgentTaskStatus status) async {
    return _tasks.values.where((t) => t.status == status).toList();
  }

  @override
  Future<List<AgentTask>> getRecent({int limit = 50}) async {
    final sorted = _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> delete(String id) async {
    _tasks.remove(id);
    _notifyListeners();
  }

  @override
  Future<void> clear() async {
    _tasks.clear();
    _notifyListeners();
  }

  @override
  Stream<List<AgentTask>> watchAll() {
    return _controller.stream;
  }

  void _notifyListeners() {
    _controller.add(_tasks.values.toList());
  }

  void dispose() {
    _controller.close();
  }
}
