import 'dart:convert';

enum WorkflowStatus { pending, planning, running, paused, completed, failed, cancelled }

enum TaskStatus { pending, running, completed, failed, skipped, retrying }

enum TaskExecutionMode { sequential, parallel }

enum WorkflowMessageType {
  workflowStarted,
  workflowCompleted,
  workflowFailed,
  workflowCancelled,
  taskStarted,
  taskCompleted,
  taskFailed,
  taskRetrying,
  agentMessage,
  resultReady,
}

class WorkflowTask {
  final String id;
  final String agentType;
  final String toolName;
  final String description;
  final Map<String, dynamic> parameters;
  final List<String> dependsOn;
  final int priority;
  final int maxRetries;
  final Duration timeout;
  TaskStatus status;
  String? result;
  String? error;
  int retryCount;
  DateTime? startedAt;
  DateTime? completedAt;
  final List<String> outputKeys;

  WorkflowTask({
    required this.id,
    required this.agentType,
    required this.toolName,
    required this.description,
    this.parameters = const {},
    this.dependsOn = const [],
    this.priority = 0,
    this.maxRetries = 2,
    this.timeout = const Duration(minutes: 5),
    this.status = TaskStatus.pending,
    this.result,
    this.error,
    this.retryCount = 0,
    this.startedAt,
    this.completedAt,
    this.outputKeys = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'agentType': agentType,
    'toolName': toolName,
    'description': description,
    'parameters': parameters,
    'dependsOn': dependsOn,
    'priority': priority,
    'maxRetries': maxRetries,
    'timeout': timeout.inSeconds,
    'status': status.name,
    'result': result,
    'error': error,
    'retryCount': retryCount,
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'outputKeys': outputKeys,
  };

  factory WorkflowTask.fromMap(Map<String, dynamic> m) => WorkflowTask(
    id: m['id'] ?? '',
    agentType: m['agentType'] ?? '',
    toolName: m['toolName'] ?? '',
    description: m['description'] ?? '',
    parameters: Map<String, dynamic>.from(m['parameters'] ?? {}),
    dependsOn: List<String>.from(m['dependsOn'] ?? []),
    priority: m['priority'] ?? 0,
    maxRetries: m['maxRetries'] ?? 2,
    timeout: Duration(seconds: m['timeout'] ?? 300),
    status: TaskStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => TaskStatus.pending),
    result: m['result'],
    error: m['error'],
    retryCount: m['retryCount'] ?? 0,
    startedAt: m['startedAt'] != null ? DateTime.parse(m['startedAt']) : null,
    completedAt: m['completedAt'] != null ? DateTime.parse(m['completedAt']) : null,
    outputKeys: List<String>.from(m['outputKeys'] ?? []),
  );
}

class Workflow {
  final String id;
  final String goal;
  final String? description;
  WorkflowStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  final List<WorkflowTask> tasks;
  final Map<String, dynamic> context;
  String? errorMessage;
  final List<String> memoryTags;

  Workflow({
    required this.id,
    required this.goal,
    this.description,
    this.status = WorkflowStatus.pending,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.tasks = const [],
    this.context = const {},
    this.errorMessage,
    this.memoryTags = const [],
  });

  double get progress {
    if (tasks.isEmpty) return 0;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
    return completed / tasks.length;
  }

  int get completedCount => tasks.where((t) => t.status == TaskStatus.completed).length;
  int get failedCount => tasks.where((t) => t.status == TaskStatus.failed).length;
  int get pendingCount => tasks.where((t) => t.status == TaskStatus.pending).length;
  int get runningCount => tasks.where((t) => t.status == TaskStatus.running).length;

  List<WorkflowTask> get readyTasks {
    return tasks.where((t) {
      if (t.status != TaskStatus.pending) return false;
      return t.dependsOn.every((depId) {
        final dep = tasks.where((t) => t.id == depId);
        return dep.isNotEmpty && dep.first.status == TaskStatus.completed;
      });
    }).toList();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'goal': goal,
    'description': description,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'tasks': tasks.map((t) => t.toMap()).toList(),
    'context': context,
    'errorMessage': errorMessage,
    'memoryTags': memoryTags,
  };

  factory Workflow.fromMap(Map<String, dynamic> m) => Workflow(
    id: m['id'] ?? '',
    goal: m['goal'] ?? '',
    description: m['description'],
    status: WorkflowStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => WorkflowStatus.pending),
    createdAt: DateTime.parse(m['createdAt']),
    startedAt: m['startedAt'] != null ? DateTime.parse(m['startedAt']) : null,
    completedAt: m['completedAt'] != null ? DateTime.parse(m['completedAt']) : null,
    tasks: (m['tasks'] as List? ?? []).map((t) => WorkflowTask.fromMap(t)).toList(),
    context: Map<String, dynamic>.from(m['context'] ?? {}),
    errorMessage: m['errorMessage'],
    memoryTags: List<String>.from(m['memoryTags'] ?? []),
  );

  String toJson() => jsonEncode(toMap());
}

class WorkflowResult {
  final String workflowId;
  final String goal;
  final WorkflowStatus status;
  final double progress;
  final int totalTasks;
  final int completedTasks;
  final int failedTasks;
  final Map<String, dynamic> results;
  final DateTime completedAt;
  final Duration duration;

  WorkflowResult({
    required this.workflowId,
    required this.goal,
    required this.status,
    required this.progress,
    required this.totalTasks,
    required this.completedTasks,
    required this.failedTasks,
    this.results = const {},
    required this.completedAt,
    required this.duration,
  });

  String get summary {
    if (status == WorkflowStatus.completed) {
      return 'Workflow completed: $goal ($completedTasks/$totalTasks tasks)';
    } else if (status == WorkflowStatus.failed) {
      return 'Workflow failed: $goal ($failedTasks/$totalTasks tasks failed)';
    }
    return 'Workflow $status: $goal';
  }

  Map<String, dynamic> toMap() => {
    'workflowId': workflowId,
    'goal': goal,
    'status': status.name,
    'progress': progress,
    'totalTasks': totalTasks,
    'completedTasks': completedTasks,
    'failedTasks': failedTasks,
    'results': results,
    'completedAt': completedAt.toIso8601String(),
    'duration': duration.inSeconds,
  };

  String toJson() => jsonEncode(toMap());
}
