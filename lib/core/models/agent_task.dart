import 'package:uuid/uuid.dart';

enum AgentTaskStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}

class AgentTask {
  final String id;
  final String agentId;
  final String title;
  final String description;
  final double progress;
  final AgentTaskStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? result;
  final String? error;
  final Map<String, dynamic> metadata;

  const AgentTask({
    required this.id,
    required this.agentId,
    required this.title,
    required this.description,
    this.progress = 0.0,
    this.status = AgentTaskStatus.pending,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.result,
    this.error,
    this.metadata = const {},
  });

  factory AgentTask.create({
    required String agentId,
    required String title,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) {
    return AgentTask(
      id: const Uuid().v4(),
      agentId: agentId,
      title: title,
      description: description,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }

  AgentTask copyWith({
    String? id,
    String? agentId,
    String? title,
    String? description,
    double? progress,
    AgentTaskStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? result,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return AgentTask(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      title: title ?? this.title,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agentId': agentId,
      'title': title,
      'description': description,
      'progress': progress,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'result': result,
      'error': error,
      'metadata': metadata,
    };
  }

  factory AgentTask.fromMap(Map<String, dynamic> map) {
    return AgentTask(
      id: map['id'] as String,
      agentId: map['agentId'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      progress: (map['progress'] as num).toDouble(),
      status: AgentTaskStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AgentTaskStatus.pending,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      startedAt: map['startedAt'] != null
          ? DateTime.parse(map['startedAt'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      result: map['result'] as String?,
      error: map['error'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  bool get isRunning => status == AgentTaskStatus.inProgress;
  bool get isDone => status == AgentTaskStatus.completed;
  bool get hasFailed => status == AgentTaskStatus.failed;
}
