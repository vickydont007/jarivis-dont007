enum TaskStatus { pending, running, completed, failed, cancelled }
enum TaskPriority { low, medium, high, critical }

class JarvisTask {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final String? result;
  final String? error;
  final Map<String, dynamic> metadata;

  JarvisTask({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    DateTime? createdAt,
    this.scheduledAt,
    this.completedAt,
    this.result,
    this.error,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  JarvisTask copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? completedAt,
    String? result,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return JarvisTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.name,
    'priority': priority.name,
    'createdAt': createdAt.toIso8601String(),
    'scheduledAt': scheduledAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'result': result,
    'error': error,
    'metadata': metadata,
  };

  factory JarvisTask.fromJson(Map<String, dynamic> json) => JarvisTask(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    status: TaskStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TaskStatus.pending,
    ),
    priority: TaskPriority.values.firstWhere(
      (e) => e.name == json['priority'],
      orElse: () => TaskPriority.medium,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    scheduledAt: json['scheduledAt'] != null
        ? DateTime.parse(json['scheduledAt'] as String)
        : null,
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    result: json['result'] as String?,
    error: json['error'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>? ?? {},
  );
}
