import 'package:uuid/uuid.dart';

enum AgentStatus {
  idle,
  working,
  completed,
  failed,
}

class Agent {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AgentStatus status;
  final String? currentTask;
  final double progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRun;
  final int totalTasks;
  final int completedTasks;
  final int failedTasks;
  final Map<String, dynamic> metadata;

  const Agent({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.status = AgentStatus.idle,
    this.currentTask,
    this.progress = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.lastRun,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.failedTasks = 0,
    this.metadata = const {},
  });

  factory Agent.create({
    required String name,
    required String description,
    required String icon,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    return Agent(
      id: const Uuid().v4(),
      name: name,
      description: description,
      icon: icon,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  Agent copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    AgentStatus? status,
    String? currentTask,
    double? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRun,
    int? totalTasks,
    int? completedTasks,
    int? failedTasks,
    Map<String, dynamic>? metadata,
  }) {
    return Agent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      currentTask: currentTask ?? this.currentTask,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRun: lastRun ?? this.lastRun,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'status': status.name,
      'currentTask': currentTask,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastRun': lastRun?.toIso8601String(),
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'failedTasks': failedTasks,
      'metadata': metadata,
    };
  }

  factory Agent.fromMap(Map<String, dynamic> map) {
    return Agent(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      status: AgentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AgentStatus.idle,
      ),
      currentTask: map['currentTask'] as String?,
      progress: (map['progress'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      lastRun: map['lastRun'] != null
          ? DateTime.parse(map['lastRun'] as String)
          : null,
      totalTasks: map['totalTasks'] as int? ?? 0,
      completedTasks: map['completedTasks'] as int? ?? 0,
      failedTasks: map['failedTasks'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  bool get isActive => status == AgentStatus.working;
  bool get isIdle => status == AgentStatus.idle;
  bool get hasFailed => status == AgentStatus.failed;
}
