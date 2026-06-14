import 'package:uuid/uuid.dart';

enum ActivityType {
  memoryCreated,
  memoryUpdated,
  memoryDeleted,
  agentStarted,
  agentCompleted,
  agentFailed,
  agentProgress,
  automationExecuted,
  automationScheduled,
  voiceSessionStarted,
  voiceSessionEnded,
  fileProcessed,
  desktopActionExecuted,
  conversationStarted,
  conversationEnded,
  briefingGenerated,
  systemEvent,
  toolUsed,
  error,
}

class ActivityEvent {
  final String id;
  final DateTime timestamp;
  final String source;
  final ActivityType type;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;

  const ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.type,
    required this.title,
    required this.description,
    this.metadata = const {},
  });

  factory ActivityEvent.create({
    required String source,
    required ActivityType type,
    required String title,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) {
    return ActivityEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      source: source,
      type: type,
      title: title,
      description: description,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'type': type.name,
      'title': title,
      'description': description,
      'metadata': metadata,
    };
  }

  factory ActivityEvent.fromMap(Map<String, dynamic> map) {
    return ActivityEvent(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      source: map['source'] as String,
      type: ActivityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityType.systemEvent,
      ),
      title: map['title'] as String,
      description: map['description'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  ActivityEvent copyWith({
    String? id,
    DateTime? timestamp,
    String? source,
    ActivityType? type,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  String toString() => 'ActivityEvent(${type.name}: $title)';
}
