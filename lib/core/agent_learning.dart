import 'dart:async';

enum TaskOutcome {
  success,
  failure,
  partial,
  timeout,
}

class TaskRecord {
  final String id;
  final String agentId;
  final String taskDescription;
  final List<String> toolsUsed;
  final TaskOutcome outcome;
  final String? error;
  final DateTime timestamp;
  final Duration duration;
  final Map<String, dynamic> metadata;

  TaskRecord({
    required this.id,
    required this.agentId,
    required this.taskDescription,
    required this.toolsUsed,
    required this.outcome,
    this.error,
    required this.timestamp,
    required this.duration,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'agent_id': agentId,
    'task_description': taskDescription,
    'tools_used': toolsUsed,
    'outcome': outcome.name,
    'error': error,
    'timestamp': timestamp.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'metadata': metadata,
  };

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      id: json['id'],
      agentId: json['agent_id'],
      taskDescription: json['task_description'],
      toolsUsed: List<String>.from(json['tools_used']),
      outcome: TaskOutcome.values.firstWhere(
        (o) => o.name == json['outcome'],
        orElse: () => TaskOutcome.failure,
      ),
      error: json['error'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: Duration(milliseconds: json['duration_ms']),
      metadata: json['metadata'] ?? {},
    );
  }
}

class AgentPerformance {
  final String agentId;
  final int totalTasks;
  final int successfulTasks;
  final int failedTasks;
  final int partialTasks;
  final Duration averageDuration;
  final List<String> commonTools;
  final double successRate;

  AgentPerformance({
    required this.agentId,
    required this.totalTasks,
    required this.successfulTasks,
    required this.failedTasks,
    required this.partialTasks,
    required this.averageDuration,
    required this.commonTools,
    required this.successRate,
  });

  Map<String, dynamic> toJson() => {
    'agent_id': agentId,
    'total_tasks': totalTasks,
    'successful_tasks': successfulTasks,
    'failed_tasks': failedTasks,
    'partial_tasks': partialTasks,
    'average_duration_ms': averageDuration.inMilliseconds,
    'common_tools': commonTools,
    'success_rate': successRate,
  };
}

class AgentLearning {
  final List<TaskRecord> _records = [];
  final StreamController<TaskRecord> _recordController =
      StreamController<TaskRecord>.broadcast();

  Stream<TaskRecord> get recordStream => _recordController.stream;
  List<TaskRecord> get records => List.unmodifiable(_records);

  void recordTask({
    required String agentId,
    required String taskDescription,
    required List<String> toolsUsed,
    required TaskOutcome outcome,
    String? error,
    required Duration duration,
    Map<String, dynamic> metadata = const {},
  }) {
    final record = TaskRecord(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      agentId: agentId,
      taskDescription: taskDescription,
      toolsUsed: toolsUsed,
      outcome: outcome,
      error: error,
      timestamp: DateTime.now(),
      duration: duration,
      metadata: metadata,
    );

    _records.add(record);
    _recordController.add(record);
  }

  AgentPerformance getPerformance(String agentId) {
    final agentRecords = _records.where((r) => r.agentId == agentId).toList();
    if (agentRecords.isEmpty) {
      return AgentPerformance(
        agentId: agentId,
        totalTasks: 0,
        successfulTasks: 0,
        failedTasks: 0,
        partialTasks: 0,
        averageDuration: Duration.zero,
        commonTools: [],
        successRate: 0.0,
      );
    }

    final successful = agentRecords.where((r) => r.outcome == TaskOutcome.success).length;
    final failed = agentRecords.where((r) => r.outcome == TaskOutcome.failure).length;
    final partial = agentRecords.where((r) => r.outcome == TaskOutcome.partial).length;

    final totalDuration = agentRecords.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.duration,
    );
    final avgDuration = totalDuration ~/ agentRecords.length;

    final toolCounts = <String, int>{};
    for (final record in agentRecords) {
      for (final tool in record.toolsUsed) {
        toolCounts[tool] = (toolCounts[tool] ?? 0) + 1;
      }
    }
    final sortedTools = toolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final commonTools = sortedTools.take(5).map((e) => e.key).toList();

    return AgentPerformance(
      agentId: agentId,
      totalTasks: agentRecords.length,
      successfulTasks: successful,
      failedTasks: failed,
      partialTasks: partial,
      averageDuration: avgDuration,
      commonTools: commonTools,
      successRate: successful / agentRecords.length,
    );
  }

  Map<String, AgentPerformance> getAllPerformance() {
    final agentIds = _records.map((r) => r.agentId).toSet();
    return {
      for (final id in agentIds) id: getPerformance(id),
    };
  }

  List<TaskRecord> getRecentRecords({int limit = 10}) {
    final sorted = List<TaskRecord>.from(_records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  List<TaskRecord> getFailedRecords({int limit = 10}) {
    return _records
        .where((r) => r.outcome == TaskOutcome.failure)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    // take(limit) applied after sort
  }

  List<String> getSuggestedImprovements(String agentId) {
    final performance = getPerformance(agentId);
    final suggestions = <String>[];

    if (performance.successRate < 0.7) {
      suggestions.add('Success rate is low (${(performance.successRate * 100).toStringAsFixed(0)}%). Consider reviewing task approach.');
    }

    final failedRecords = _records
        .where((r) => r.agentId == agentId && r.outcome == TaskOutcome.failure)
        .toList();

    final errorPatterns = <String, int>{};
    for (final record in failedRecords) {
      if (record.error != null) {
        final errorKey = record.error!.length > 50
            ? record.error!.substring(0, 50)
            : record.error!;
        errorPatterns[errorKey] = (errorPatterns[errorKey] ?? 0) + 1;
      }
    }

    for (final entry in errorPatterns.entries) {
      if (entry.value > 2) {
        suggestions.add('Recurring error: "${entry.key}" (occurred ${entry.value} times)');
      }
    }

    if (performance.averageDuration.inSeconds > 30) {
      suggestions.add('Average task duration is high (${performance.averageDuration.inSeconds}s). Consider optimizing.');
    }

    return suggestions;
  }

  Map<String, dynamic> getStats() {
    final total = _records.length;
    final successful = _records.where((r) => r.outcome == TaskOutcome.success).length;
    final failed = _records.where((r) => r.outcome == TaskOutcome.failure).length;

    return {
      'total_tasks': total,
      'successful': successful,
      'failed': failed,
      'success_rate': total > 0 ? successful / total : 0.0,
      'unique_agents': _records.map((r) => r.agentId).toSet().length,
    };
  }

  void clear() {
    _records.clear();
  }

  void dispose() {
    _recordController.close();
  }
}
