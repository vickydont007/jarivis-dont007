import 'dart:ui';

enum AgentRole {
  orchestrator,
  outreach,
  content,
  dm,
  comment,
  lead,
  research,
  monitor,
  code,
  scheduler,
  custom,
}

enum AgentStatus {
  idle,
  active,
  busy,
  failed,
  spawning,
  terminated,
}

class AgentMessage {
  final String fromId;
  final String toId;
  final String content;
  final DateTime timestamp;
  final String? taskId;

  AgentMessage({
    required this.fromId,
    required this.toId,
    required this.content,
    required this.taskId,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toMap() => {
        'from': fromId,
        'to': toId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'taskId': taskId,
      };
}

class DynamicAgent {
  final String id;
  String name;
  AgentRole role;
  AgentStatus status;
  Color color;
  String icon;
  Offset position;
  Offset velocity;
  final DateTime spawnTime;
  int tasksCompleted;
  int tasksFailed;
  DateTime? lastActive;
  String? lastTaskResult;
  String? currentTask;
  String description;
  double progress;
  List<String> connectedAgentIds;
  Map<String, dynamic> metadata;

  DynamicAgent({
    required this.id,
    required this.name,
    required this.role,
    this.status = AgentStatus.spawning,
    Color? color,
    String? icon,
    Offset? position,
    Offset? velocity,
    DateTime? spawnTime,
    this.tasksCompleted = 0,
    this.tasksFailed = 0,
    this.lastActive,
    this.lastTaskResult,
    this.currentTask,
    this.description = '',
    this.progress = 0.0,
    List<String>? connectedAgentIds,
    Map<String, dynamic>? metadata,
  })  : color = color ?? _getColorForRole(role),
        icon = icon ?? _getIconForRole(role),
        position = position ?? Offset.zero,
        velocity = velocity ?? Offset.zero,
        spawnTime = spawnTime ?? DateTime.now(),
        connectedAgentIds = connectedAgentIds ?? [],
        metadata = metadata ?? {};

  static Color _getColorForRole(AgentRole role) {
    switch (role) {
      case AgentRole.orchestrator:
        return const Color(0xFF00BCD4);
      case AgentRole.outreach:
        return const Color(0xFF2196F3);
      case AgentRole.content:
        return const Color(0xFF9C27B0);
      case AgentRole.dm:
        return const Color(0xFF4CAF50);
      case AgentRole.comment:
        return const Color(0xFFFF9800);
      case AgentRole.lead:
        return const Color(0xFFF44336);
      case AgentRole.research:
        return const Color(0xFF009688);
      case AgentRole.monitor:
        return const Color(0xFFFFC107);
      case AgentRole.code:
        return const Color(0xFFE91E63);
      case AgentRole.scheduler:
        return const Color(0xFF3F51B5);
      case AgentRole.custom:
        return const Color(0xFF9E9E9E);
    }
  }

  static String _getIconForRole(AgentRole role) {
    switch (role) {
      case AgentRole.orchestrator:
        return 'hub';
      case AgentRole.outreach:
        return 'send';
      case AgentRole.content:
        return 'palette';
      case AgentRole.dm:
        return 'chat';
      case AgentRole.comment:
        return 'comment';
      case AgentRole.lead:
        return 'target';
      case AgentRole.research:
        return 'search';
      case AgentRole.monitor:
        return 'eye';
      case AgentRole.code:
        return 'code';
      case AgentRole.scheduler:
        return 'schedule';
      case AgentRole.custom:
        return 'extension';
    }
  }

  double get uptimeSeconds =>
      DateTime.now().difference(spawnTime).inSeconds.toDouble();

  String get uptimeFormatted {
    final diff = DateTime.now().difference(spawnTime);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return '+${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get isActive => status == AgentStatus.active || status == AgentStatus.busy;
  bool get isAlive => status != AgentStatus.terminated;

  void activate() {
    status = AgentStatus.active;
    lastActive = DateTime.now();
  }

  void deactivate() {
    status = AgentStatus.idle;
  }

  void markBusy() {
    status = AgentStatus.busy;
    lastActive = DateTime.now();
  }

  void markComplete({bool success = true, String? result}) {
    if (success) {
      tasksCompleted++;
      lastTaskResult = result;
      status = AgentStatus.active;
    } else {
      tasksFailed++;
      status = AgentStatus.failed;
    }
    lastActive = DateTime.now();
  }

  void terminate() {
    status = AgentStatus.terminated;
  }

  void connectTo(String agentId) {
    if (!connectedAgentIds.contains(agentId)) {
      connectedAgentIds.add(agentId);
    }
  }

  void disconnectFrom(String agentId) {
    connectedAgentIds.remove(agentId);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role.name,
        'status': status.name,
        'tasksCompleted': tasksCompleted,
        'tasksFailed': tasksFailed,
        'spawnTime': spawnTime.toIso8601String(),
        'lastActive': lastActive?.toIso8601String(),
        'connections': connectedAgentIds,
        'currentTask': currentTask,
        'description': description,
        'progress': progress,
      };

  static int _idCounter = 0;

  factory DynamicAgent.create({
    required String name,
    required AgentRole role,
    Offset? position,
    List<String> connections = const [],
  }) {
    _idCounter++;
    return DynamicAgent(
      id: 'agent_${_idCounter}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: role,
      status: AgentStatus.spawning,
      position: position ?? Offset.zero,
      connectedAgentIds: List.from(connections),
    );
  }

  static AgentRole roleFromString(String s) {
    return AgentRole.values.firstWhere(
      (r) => r.name == s,
      orElse: () => AgentRole.custom,
    );
  }
}

class AgentConnection {
  final String fromId;
  final String toId;
  double strength;
  bool isActive;
  DateTime lastActivity;
  int messageCount;

  AgentConnection({
    required this.fromId,
    required this.toId,
    this.strength = 1.0,
    this.isActive = false,
    DateTime? lastActivity,
    this.messageCount = 0,
  }) : lastActivity = lastActivity ?? DateTime.now();

  void activate() {
    isActive = true;
    lastActivity = DateTime.now();
    messageCount++;
  }

  void deactivate() {
    isActive = false;
  }

  String get key => '${fromId}_$toId';

  Map<String, dynamic> toMap() => {
        'from': fromId,
        'to': toId,
        'strength': strength,
        'isActive': isActive,
        'messageCount': messageCount,
      };
}
