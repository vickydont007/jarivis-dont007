import 'dart:async';
import '../models/agent.dart';

abstract class AgentRepository {
  Future<void> save(Agent agent);
  Future<void> saveAll(List<Agent> agents);
  Future<Agent?> getById(String id);
  Future<List<Agent>> getAll();
  Future<List<Agent>> getByStatus(AgentStatus status);
  Future<void> delete(String id);
  Future<void> clear();
  Stream<List<Agent>> watchAll();
}

class InMemoryAgentRepository implements AgentRepository {
  final Map<String, Agent> _agents = {};
  final StreamController<List<Agent>> _controller =
      StreamController<List<Agent>>.broadcast();

  @override
  Future<void> save(Agent agent) async {
    _agents[agent.id] = agent;
    _notifyListeners();
  }

  @override
  Future<void> saveAll(List<Agent> agents) async {
    for (final agent in agents) {
      _agents[agent.id] = agent;
    }
    _notifyListeners();
  }

  @override
  Future<Agent?> getById(String id) async => _agents[id];

  @override
  Future<List<Agent>> getAll() async =>
      _agents.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<List<Agent>> getByStatus(AgentStatus status) async {
    return _agents.values.where((a) => a.status == status).toList();
  }

  @override
  Future<void> delete(String id) async {
    _agents.remove(id);
    _notifyListeners();
  }

  @override
  Future<void> clear() async {
    _agents.clear();
    _notifyListeners();
  }

  @override
  Stream<List<Agent>> watchAll() {
    return _controller.stream;
  }

  void _notifyListeners() {
    _controller.add(getAllSync());
  }

  List<Agent> getAllSync() =>
      _agents.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void dispose() {
    _controller.close();
  }
}
