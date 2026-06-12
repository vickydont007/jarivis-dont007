import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dynamic_agent.dart';

enum NetworkEventType {
  agentAdded,
  agentRemoved,
  agentUpdated,
  connectionAdded,
  connectionRemoved,
  messageSent,
  taskRouted,
}

class NetworkEvent {
  final NetworkEventType type;
  final dynamic data;
  final DateTime timestamp;

  NetworkEvent({
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AgentNetwork {
  final List<DynamicAgent> _agents = [];
  final List<AgentConnection> _connections = [];
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();
  final Random _random = Random();

  Stream<NetworkEvent> get eventStream => _eventController.stream;
  List<DynamicAgent> get agents => List.unmodifiable(_agents);
  List<AgentConnection> get connections => List.unmodifiable(_connections);

  int get agentCount => _agents.where((a) => a.isAlive).length;
  int get connectionCount => _connections.length;
  int get totalTasks =>
      _agents.fold(0, (sum, a) => sum + a.tasksCompleted);
  int get activeAgents => _agents.where((a) => a.isActive).length;

  DynamicAgent? getAgentById(String id) {
    try {
      return _agents.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DynamicAgent> getConnectedAgents(String agentId) {
    final ids = <String>{};
    for (final conn in _connections) {
      if (conn.fromId == agentId) ids.add(conn.toId);
      if (conn.toId == agentId) ids.add(conn.fromId);
    }
    return ids.map((id) => getAgentById(id)).whereType<DynamicAgent>().toList();
  }

  AgentConnection? getConnection(String fromId, String toId) {
    try {
      return _connections.firstWhere(
        (c) => (c.fromId == fromId && c.toId == toId) ||
            (c.fromId == toId && c.toId == fromId),
      );
    } catch (_) {
      return null;
    }
  }

  DynamicAgent spawnAgent({
    required String name,
    required AgentRole role,
    Offset? position,
    List<String> connectTo = const [],
  }) {
    final agent = DynamicAgent.create(
      name: name,
      role: role,
      position: position ?? _randomPosition(),
      connections: connectTo,
    );

    _agents.add(agent);

    for (final targetId in connectTo) {
      _addConnectionInternal(agent.id, targetId);
    }

    _eventController.add(NetworkEvent(
      type: NetworkEventType.agentAdded,
      data: agent,
    ));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (agent.isAlive) {
        agent.activate();
        _eventController.add(NetworkEvent(
          type: NetworkEventType.agentUpdated,
          data: agent,
        ));
      }
    });

    return agent;
  }

  void removeAgent(String agentId) {
    final agent = getAgentById(agentId);
    if (agent == null) return;

    agent.terminate();

    _connections.removeWhere(
      (c) => c.fromId == agentId || c.toId == agentId,
    );

    _eventController.add(NetworkEvent(
      type: NetworkEventType.agentRemoved,
      data: agent,
    ));
  }

  void connect(String fromId, String toId) {
    _addConnectionInternal(fromId, toId);
  }

  void disconnect(String fromId, String toId) {
    _connections.removeWhere(
      (c) => (c.fromId == fromId && c.toId == toId) ||
          (c.fromId == toId && c.toId == fromId),
    );

    final from = getAgentById(fromId);
    final to = getAgentById(toId);
    from?.disconnectFrom(toId);
    to?.disconnectFrom(fromId);

    _eventController.add(NetworkEvent(
      type: NetworkEventType.connectionRemoved,
      data: {'from': fromId, 'to': toId},
    ));
  }

  void sendMessage(String fromId, String toId, String content, {String? taskId}) {
    final from = getAgentById(fromId);
    final to = getAgentById(toId);
    if (from == null || to == null) return;

    final msg = AgentMessage(
      fromId: fromId,
      toId: toId,
      content: content,
      taskId: taskId,
    );

    final conn = getConnection(fromId, toId);
    conn?.activate();

    _eventController.add(NetworkEvent(
      type: NetworkEventType.messageSent,
      data: msg,
    ));
  }

  String routeTask(String taskDescription) {
    final lower = taskDescription.toLowerCase();

    if (lower.contains('outreach') || lower.contains('message') || lower.contains('contact')) {
      return _findAgentByRole(AgentRole.outreach) ?? _findDefaultAgent();
    }
    if (lower.contains('content') || lower.contains('post') || lower.contains('write')) {
      return _findAgentByRole(AgentRole.content) ?? _findDefaultAgent();
    }
    if (lower.contains('dm') || lower.contains('direct message')) {
      return _findAgentByRole(AgentRole.dm) ?? _findDefaultAgent();
    }
    if (lower.contains('comment') || lower.contains('reply') || lower.contains('engage')) {
      return _findAgentByRole(AgentRole.comment) ?? _findDefaultAgent();
    }
    if (lower.contains('lead') || lower.contains('find') || lower.contains('prospect')) {
      return _findAgentByRole(AgentRole.lead) ?? _findDefaultAgent();
    }
    if (lower.contains('research') || lower.contains('analyze') || lower.contains('search')) {
      return _findAgentByRole(AgentRole.research) ?? _findDefaultAgent();
    }
    if (lower.contains('monitor') || lower.contains('watch') || lower.contains('track')) {
      return _findAgentByRole(AgentRole.monitor) ?? _findDefaultAgent();
    }
    if (lower.contains('code') || lower.contains('bug') || lower.contains('program')) {
      return _findAgentByRole(AgentRole.code) ?? _findDefaultAgent();
    }
    if (lower.contains('schedule') || lower.contains('remind') || lower.contains('timer')) {
      return _findAgentByRole(AgentRole.scheduler) ?? _findDefaultAgent();
    }

    return _findAgentByRole(AgentRole.orchestrator) ?? _findDefaultAgent();
  }

  void applyForceLayout(Rect bounds, {double iterations = 50}) {
    if (_agents.length < 2) return;

    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final repulsionForce = 5000.0;
    final attractionForce = 0.01;
    final centerGravity = 0.005;
    final damping = 0.9;

    for (final agent in _agents) {
      agent.velocity = Offset.zero;
    }

    for (int i = 0; i < iterations.toInt(); i++) {
      for (int a = 0; a < _agents.length; a++) {
        for (int b = a + 1; b < _agents.length; b++) {
          final agentA = _agents[a];
          final agentB = _agents[b];
          final diff = agentA.position - agentB.position;
          final dist = diff.distance.clamp(1.0, 500.0);
          final force = repulsionForce / (dist * dist);
          final dir = diff / dist;
          agentA.velocity += dir * force * 0.1;
          agentB.velocity -= dir * force * 0.1;
        }
      }

      for (final conn in _connections) {
        final from = getAgentById(conn.fromId);
        final to = getAgentById(conn.toId);
        if (from == null || to == null) continue;

        final diff = to.position - from.position;
        final dist = diff.distance;
        final force = (dist - 150) * attractionForce;
        final dir = diff / dist.clamp(1.0, 500.0);

        from.velocity += dir * force;
        to.velocity -= dir * force;
      }

      for (final agent in _agents) {
        final toCenter = Offset(centerX, centerY) - agent.position;
        agent.velocity += toCenter * centerGravity;
        agent.velocity *= damping;
        agent.position += agent.velocity * 0.1;

        agent.position = Offset(
          agent.position.dx.clamp(bounds.left + 50, bounds.right - 50),
          agent.position.dy.clamp(bounds.top + 80, bounds.bottom - 50),
        );
      }
    }
  }

  void updatePositions(double dt) {
    for (final agent in _agents) {
      agent.position += agent.velocity * dt;
      agent.velocity *= 0.98;
    }
  }

  DynamicAgent? getNodeAtPosition(Offset position, {double radius = 30}) {
    for (final agent in _agents.reversed) {
      if ((agent.position - position).distance <= radius) {
        return agent;
      }
    }
    return null;
  }

  void _addConnectionInternal(String fromId, String toId) {
    final existing = getConnection(fromId, toId);
    if (existing != null) return;

    final conn = AgentConnection(fromId: fromId, toId: toId);
    _connections.add(conn);

    final from = getAgentById(fromId);
    final to = getAgentById(toId);
    from?.connectTo(toId);
    to?.connectTo(fromId);

    _eventController.add(NetworkEvent(
      type: NetworkEventType.connectionAdded,
      data: conn,
    ));
  }

  Offset _randomPosition() {
    return Offset(
      200 + _random.nextDouble() * 600,
      150 + _random.nextDouble() * 400,
    );
  }

  String? _findAgentByRole(AgentRole role) {
    try {
      return _agents
          .where((a) => a.role == role && a.isAlive)
          .first
          .id;
    } catch (_) {
      return null;
    }
  }

  String _findDefaultAgent() {
    final alive = _agents.where((a) => a.isAlive).toList();
    if (alive.isEmpty) return '';
    return alive.first.id;
  }

  void initializeDefaultNetwork() {
    final orchestrator = spawnAgent(
      name: 'Orchestrator',
      role: AgentRole.orchestrator,
      position: const Offset(450, 280),
    );

    spawnAgent(
      name: 'Outreach',
      role: AgentRole.outreach,
      position: const Offset(200, 100),
      connectTo: [orchestrator.id],
    );

    spawnAgent(
      name: 'Content Studio',
      role: AgentRole.content,
      position: const Offset(150, 350),
      connectTo: [orchestrator.id],
    );

    final outreach = _agents.firstWhere((a) => a.role == AgentRole.outreach);
    final content = _agents.firstWhere((a) => a.role == AgentRole.content);

    spawnAgent(
      name: 'DM Agent',
      role: AgentRole.dm,
      position: const Offset(700, 120),
      connectTo: [orchestrator.id, outreach.id],
    );

    spawnAgent(
      name: 'Comment',
      role: AgentRole.comment,
      position: const Offset(750, 380),
      connectTo: [orchestrator.id, content.id],
    );

    spawnAgent(
      name: 'Lead Gen',
      role: AgentRole.lead,
      position: const Offset(300, 480),
      connectTo: [orchestrator.id, outreach.id],
    );

    spawnAgent(
      name: 'Research',
      role: AgentRole.research,
      position: const Offset(550, 460),
      connectTo: [orchestrator.id],
    );

    spawnAgent(
      name: 'Monitor',
      role: AgentRole.monitor,
      position: const Offset(80, 220),
      connectTo: [orchestrator.id],
    );

    spawnAgent(
      name: 'Code',
      role: AgentRole.code,
      position: const Offset(820, 250),
      connectTo: [orchestrator.id],
    );

    spawnAgent(
      name: 'Scheduler',
      role: AgentRole.scheduler,
      position: const Offset(450, 80),
      connectTo: [orchestrator.id],
    );

    _eventController.add(NetworkEvent(
      type: NetworkEventType.taskRouted,
      data: 'Default network initialized with 10 agents',
    ));
  }

  void dispose() {
    _eventController.close();
  }
}
