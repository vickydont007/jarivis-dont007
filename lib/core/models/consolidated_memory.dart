import 'dart:convert';

enum MemoryCategory {
  name,
  preference,
  project,
  goal,
  skill,
  interest,
  relationship,
  date,
  plan,
  fact,
  emotional,
  daily,
}

class ConsolidatedMemory {
  final String id;
  final String content;
  final MemoryCategory category;
  final int importanceScore;
  final double confidenceScore;
  final int reinforcementCount;
  final DateTime? lastReinforcedAt;
  final String source;
  final String? canonicalId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConsolidatedMemory({
    required this.id,
    required this.content,
    required this.category,
    this.importanceScore = 50,
    this.confidenceScore = 0.5,
    this.reinforcementCount = 1,
    this.lastReinforcedAt,
    this.source = 'conversation',
    this.canonicalId,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConsolidatedMemory.create({
    required String content,
    required MemoryCategory category,
    int importanceScore = 50,
    double confidenceScore = 0.5,
    String source = 'conversation',
    String? canonicalId,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    return ConsolidatedMemory(
      id: _generateId(),
      content: content,
      category: category,
      importanceScore: importanceScore,
      confidenceScore: confidenceScore,
      source: source,
      canonicalId: canonicalId,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
      lastReinforcedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'category': category.name,
      'importance_score': importanceScore,
      'confidence_score': confidenceScore,
      'reinforcement_count': reinforcementCount,
      'last_reinforced_at': lastReinforcedAt?.toIso8601String(),
      'source': source,
      'canonical_id': canonicalId,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ConsolidatedMemory.fromMap(Map<String, dynamic> map) {
    return ConsolidatedMemory(
      id: map['id'],
      content: map['content'],
      category: MemoryCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => MemoryCategory.fact,
      ),
      importanceScore: map['importance_score'] ?? 50,
      confidenceScore: (map['confidence_score'] ?? 0.5).toDouble(),
      reinforcementCount: map['reinforcement_count'] ?? 1,
      lastReinforcedAt: map['last_reinforced_at'] != null
          ? DateTime.parse(map['last_reinforced_at'])
          : null,
      source: map['source'] ?? 'conversation',
      canonicalId: map['canonical_id'],
      metadata: map['metadata'] != null
          ? jsonDecode(map['metadata'] as String)
          : {},
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (now * 1000 + (now % 1000));
    return 'cm_$random';
  }

  double get effectiveScore => importanceScore * confidenceScore;

  bool get isHighValue => importanceScore >= 70 && confidenceScore >= 0.6;

  bool get needsReinforcement =>
      reinforcementCount < 3 && confidenceScore < 0.7;
}

class UserProfile {
  final String id;
  final String fieldName;
  final String fieldValue;
  final double confidence;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.fieldName,
    required this.fieldValue,
    this.confidence = 0.5,
    this.source = 'conversation',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'field_name': fieldName,
      'field_value': fieldValue,
      'confidence': confidence,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      fieldName: map['field_name'],
      fieldValue: map['field_value'],
      confidence: (map['confidence'] ?? 0.5).toDouble(),
      source: map['source'] ?? 'conversation',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'up_$now';
  }
}

class MemoryLink {
  final String id;
  final String fromMemoryId;
  final String toMemoryId;
  final String relationship;
  final double strength;
  final DateTime createdAt;

  MemoryLink({
    required this.id,
    required this.fromMemoryId,
    required this.toMemoryId,
    required this.relationship,
    this.strength = 0.5,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_memory_id': fromMemoryId,
      'to_memory_id': toMemoryId,
      'relationship': relationship,
      'strength': strength,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MemoryLink.fromMap(Map<String, dynamic> map) {
    return MemoryLink(
      id: map['id'],
      fromMemoryId: map['from_memory_id'],
      toMemoryId: map['to_memory_id'],
      relationship: map['relationship'],
      strength: (map['strength'] ?? 0.5).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
