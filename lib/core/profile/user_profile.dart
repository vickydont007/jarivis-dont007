import 'dart:convert';

class UserProfile {
  final String id;
  final String userId;
  String name;
  String nickname;
  String occupation;
  String company;
  List<String> projects;
  List<String> goals;
  List<String> skills;
  List<String> interests;
  Map<String, dynamic> preferences;
  List<Map<String, dynamic>> relationships;
  List<Map<String, dynamic>> importantDates;
  String location;
  String bio;
  double confidenceScore;
  double completenessScore;
  DateTime createdAt;
  DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    this.name = '',
    this.nickname = '',
    this.occupation = '',
    this.company = '',
    List<String>? projects,
    List<String>? goals,
    List<String>? skills,
    List<String>? interests,
    Map<String, dynamic>? preferences,
    List<Map<String, dynamic>>? relationships,
    List<Map<String, dynamic>>? importantDates,
    this.location = '',
    this.bio = '',
    this.confidenceScore = 0.0,
    this.completenessScore = 0.0,
    required this.createdAt,
    required this.updatedAt,
  })  : projects = projects ?? [],
        goals = goals ?? [],
        skills = skills ?? [],
        interests = interests ?? [],
        preferences = preferences ?? {},
        relationships = relationships ?? [],
        importantDates = importantDates ?? [];

  factory UserProfile.create({required String userId}) {
    final now = DateTime.now();
    return UserProfile(
      id: _generateId(),
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'nickname': nickname,
      'occupation': occupation,
      'company': company,
      'projects': jsonEncode(projects),
      'goals': jsonEncode(goals),
      'skills': jsonEncode(skills),
      'interests': jsonEncode(interests),
      'preferences': jsonEncode(preferences),
      'relationships': jsonEncode(relationships),
      'important_dates': jsonEncode(importantDates),
      'location': location,
      'bio': bio,
      'confidence_score': confidenceScore,
      'completeness_score': completenessScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'] ?? '',
      nickname: map['nickname'] ?? '',
      occupation: map['occupation'] ?? '',
      company: map['company'] ?? '',
      projects: _parseStringList(map['projects']),
      goals: _parseStringList(map['goals']),
      skills: _parseStringList(map['skills']),
      interests: _parseStringList(map['interests']),
      preferences: _parseMap(map['preferences']),
      relationships: _parseListOfMaps(map['relationships']),
      importantDates: _parseListOfMaps(map['important_dates']),
      location: map['location'] ?? '',
      bio: map['bio'] ?? '',
      confidenceScore: (map['confidence_score'] ?? 0.0).toDouble(),
      completenessScore: (map['completeness_score'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? occupation,
    String? company,
    List<String>? projects,
    List<String>? goals,
    List<String>? skills,
    List<String>? interests,
    Map<String, dynamic>? preferences,
    List<Map<String, dynamic>>? relationships,
    List<Map<String, dynamic>>? importantDates,
    String? location,
    String? bio,
    double? confidenceScore,
    double? completenessScore,
  }) {
    return UserProfile(
      id: id,
      userId: userId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      occupation: occupation ?? this.occupation,
      company: company ?? this.company,
      projects: projects ?? this.projects,
      goals: goals ?? this.goals,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      preferences: preferences ?? this.preferences,
      relationships: relationships ?? this.relationships,
      importantDates: importantDates ?? this.importantDates,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      completenessScore: completenessScore ?? this.completenessScore,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'prof_$now';
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    try {
      return List<String>.from(jsonDecode(value as String));
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) return Map<String, dynamic>.from(value);
    try {
      return Map<String, dynamic>.from(jsonDecode(value as String));
    } catch (_) {
      return {};
    }
  }

  static List<Map<String, dynamic>> _parseListOfMaps(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<Map<String, dynamic>>();
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(value as String));
    } catch (_) {
      return [];
    }
  }
}
