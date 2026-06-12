import 'dart:async';

enum ActivityType {
  toolCall,
  agentSpawn,
  agentKill,
  taskRouted,
  taskCompleted,
  taskFailed,
  memoryAdded,
  memorySearched,
  codeExecuted,
  systemEvent,
}

class ActivityEvent {
  final String id;
  final ActivityType type;
  final String source;
  final String description;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ActivityEvent({
    required this.id,
    required this.type,
    required this.source,
    required this.description,
    this.data = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'source': source,
    'description': description,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };
}

class SystemMetrics {
  final int totalToolCalls;
  final int activeAgents;
  final int pendingTasks;
  final int completedTasks;
  final int failedTasks;
  final int memoryEntries;
  final Duration uptime;
  final double successRate;

  SystemMetrics({
    required this.totalToolCalls,
    required this.activeAgents,
    required this.pendingTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.memoryEntries,
    required this.uptime,
    required this.successRate,
  });

  Map<String, dynamic> toJson() => {
    'total_tool_calls': totalToolCalls,
    'active_agents': activeAgents,
    'pending_tasks': pendingTasks,
    'completed_tasks': completedTasks,
    'failed_tasks': failedTasks,
    'memory_entries': memoryEntries,
    'uptime_seconds': uptime.inSeconds,
    'success_rate': successRate,
  };
}

class RealTimeMonitor {
  final List<ActivityEvent> _activities = [];
  final StreamController<ActivityEvent> _activityController =
      StreamController<ActivityEvent>.broadcast();
  final StreamController<SystemMetrics> _metricsController =
      StreamController<SystemMetrics>.broadcast();
  final DateTime _startTime = DateTime.now();
  int _totalToolCalls = 0;
  int _completedTasks = 0;
  int _failedTasks = 0;
  Timer? _metricsTimer;

  Stream<ActivityEvent> get activityStream => _activityController.stream;
  Stream<SystemMetrics> get metricsStream => _metricsController.stream;
  List<ActivityEvent> get activities => List.unmodifiable(_activities);

  RealTimeMonitor() {
    // Update system metrics every 5 seconds
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateMetrics();
    });
  }

  void logActivity({
    required ActivityType type,
    required String source,
    required String description,
    Map<String, dynamic> data = const {},
  }) {
    final event = ActivityEvent(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      source: source,
      description: description,
      data: data,
      timestamp: DateTime.now(),
    );

    _activities.add(event);
    _activityController.add(event);

    if (_activities.length > 1000) {
      _activities.removeRange(0, _activities.length - 1000);
    }
  }

  void logToolCall(String toolName, Map<String, dynamic> params, bool success) {
    _totalToolCalls++;
    logActivity(
      type: ActivityType.toolCall,
      source: 'ToolExecutor',
      description: 'Tool "$toolName" called ${success ? "successfully" : "failed"}',
      data: {'tool': toolName, 'params': params, 'success': success},
    );
  }

  void logAgentSpawn(String agentId, String name) {
    logActivity(
      type: ActivityType.agentSpawn,
      source: 'AgentNetwork',
      description: 'Agent "$name" spawned ($agentId)',
      data: {'agent_id': agentId, 'name': name},
    );
  }

  void logAgentKill(String agentId, String name) {
    logActivity(
      type: ActivityType.agentKill,
      source: 'AgentNetwork',
      description: 'Agent "$name" terminated ($agentId)',
      data: {'agent_id': agentId, 'name': name},
    );
  }

  void logTaskRouted(String taskId, String agentId, String description) {
    logActivity(
      type: ActivityType.taskRouted,
      source: 'TaskRouter',
      description: 'Task routed to agent: $description',
      data: {'task_id': taskId, 'agent_id': agentId},
    );
  }

  void logTaskCompleted(String taskId, String result) {
    _completedTasks++;
    logActivity(
      type: ActivityType.taskCompleted,
      source: 'TaskRouter',
      description: 'Task completed: $result',
      data: {'task_id': taskId},
    );
  }

  void logTaskFailed(String taskId, String error) {
    _failedTasks++;
    logActivity(
      type: ActivityType.taskFailed,
      source: 'TaskRouter',
      description: 'Task failed: $error',
      data: {'task_id': taskId},
    );
  }

  void logMemoryEvent(String type, String details) {
    logActivity(
      type: type == 'add' ? ActivityType.memoryAdded : ActivityType.memorySearched,
      source: 'MemorySystem',
      description: 'Memory ${type}: $details',
    );
  }

  void logCodeExecution(String language, bool success, Duration duration) {
    logActivity(
      type: ActivityType.codeExecuted,
      source: 'CodeSandbox',
      description: '$language execution ${success ? "succeeded" : "failed"} (${duration.inMilliseconds}ms)',
      data: {'language': language, 'success': success},
    );
  }

  void logSystemEvent(String description) {
    logActivity(
      type: ActivityType.systemEvent,
      source: 'System',
      description: description,
    );
  }

  void _updateMetrics() {
    _metricsController.add(getMetrics());
  }

  SystemMetrics getMetrics({int? activeAgents, int? pendingTasks, int? memoryEntries}) {
    final totalTasks = _completedTasks + _failedTasks;

    return SystemMetrics(
      totalToolCalls: _totalToolCalls,
      activeAgents: activeAgents ?? 0,
      pendingTasks: pendingTasks ?? 0,
      completedTasks: _completedTasks,
      failedTasks: _failedTasks,
      memoryEntries: memoryEntries ?? 0,
      uptime: DateTime.now().difference(_startTime),
      successRate: totalTasks > 0 ? _completedTasks / totalTasks : 1.0,
    );
  }

  List<ActivityEvent> getRecentActivities({int limit = 20}) {
    final sorted = List<ActivityEvent>.from(_activities)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  List<ActivityEvent> getActivitiesByType(ActivityType type, {int limit = 20}) {
    return _activities
        .where((a) => a.type == type)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
      ..take(limit).toList();
  }

  void clear() {
    _activities.clear();
    _totalToolCalls = 0;
    _completedTasks = 0;
    _failedTasks = 0;
  }

  void dispose() {
    _metricsTimer?.cancel();
    _activityController.close();
    _metricsController.close();
  }
}
