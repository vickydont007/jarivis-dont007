import 'package:uuid/uuid.dart';

enum MemoryType {
  fact,
  preference,
  goal,
  project,
  pattern,
}

class MemoryRecord {
  final String id;
  final MemoryType type;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source;
  final int importance;
  final Map<String, dynamic> metadata;

  const MemoryRecord({
    required this.id,
    required this.type,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    this.importance = 5,
    this.metadata = const {},
  });

  factory MemoryRecord.create({
    required MemoryType type,
    required String content,
    List<String> tags = const [],
    required String source,
    int importance = 5,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    return MemoryRecord(
      id: const Uuid().v4(),
      type: type,
      content: content,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      source: source,
      importance: importance,
      metadata: metadata,
    );
  }

  MemoryRecord copyWith({
    String? id,
    MemoryType? type,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    int? importance,
    Map<String, dynamic>? metadata,
  }) {
    return MemoryRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      source: source ?? this.source,
      importance: importance ?? this.importance,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'source': source,
      'importance': importance,
      'metadata': metadata,
    };
  }

  factory MemoryRecord.fromMap(Map<String, dynamic> map) {
    return MemoryRecord(
      id: map['id'] as String,
      type: MemoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MemoryType.fact,
      ),
      content: map['content'] as String,
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      source: map['source'] as String,
      importance: map['importance'] as int? ?? 5,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String get typeLabel {
    switch (type) {
      case MemoryType.fact:
        return 'Fact';
      case MemoryType.preference:
        return 'Preference';
      case MemoryType.goal:
        return 'Goal';
      case MemoryType.project:
        return 'Project';
      case MemoryType.pattern:
        return 'Pattern';
    }
  }
}
