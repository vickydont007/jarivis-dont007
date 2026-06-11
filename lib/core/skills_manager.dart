import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class Skill {
  final String id;
  final String name;
  final String description;
  final String category;
  final String source;
  final Map<String, dynamic> config;
  final List<String> triggers;
  final DateTime createdAt;
  final DateTime lastUsed;
  final int usageCount;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    this.category = 'general',
    this.source = 'custom',
    this.config = const {},
    this.triggers = const [],
    required this.createdAt,
    required this.lastUsed,
    this.usageCount = 0,
  });

  factory Skill.create({
    required String name,
    required String description,
    String category = 'general',
    String source = 'custom',
    Map<String, dynamic> config = const {},
    List<String> triggers = const [],
  }) {
    final now = DateTime.now();
    return Skill(
      id: const Uuid().v4(),
      name: name,
      description: description,
      category: category,
      source: source,
      config: config,
      triggers: triggers,
      createdAt: now,
      lastUsed: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'source': source,
      'config': jsonEncode(config),
      'triggers': jsonEncode(triggers),
      'created_at': createdAt.toIso8601String(),
      'last_used': lastUsed.toIso8601String(),
      'usage_count': usageCount,
    };
  }

  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      category: map['category'],
      source: map['source'],
      config: jsonDecode(map['config']),
      triggers: jsonDecode(map['triggers']),
      createdAt: DateTime.parse(map['created_at']),
      lastUsed: DateTime.parse(map['last_used']),
      usageCount: map['usage_count'],
    );
  }

  Skill copyWith({
    String? name,
    String? description,
    String? category,
    String? source,
    Map<String, dynamic>? config,
    List<String>? triggers,
    DateTime? lastUsed,
    int? usageCount,
  }) {
    return Skill(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      source: source ?? this.source,
      config: config ?? this.config,
      triggers: triggers ?? this.triggers,
      createdAt: createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

class SkillsManager {
  final List<Skill> _skills = [];
  final StreamController<Skill> _skillController = StreamController<Skill>.broadcast();

  Stream<Skill> get skillStream => _skillController.stream;
  List<Skill> get skills => List.unmodifiable(_skills);

  // Pre-built skills from Hermes/OpenClaw
  final Map<String, List<Map<String, dynamic>>> _skillSources = {
    'hermes': [
      {
        'name': 'web_search',
        'description': 'Search the web for information',
        'category': 'research',
        'triggers': ['search', 'find', 'look up', 'google'],
      },
      {
        'name': 'weather',
        'description': 'Get weather information',
        'category': 'utility',
        'triggers': ['weather', 'temperature', 'forecast'],
      },
      {
        'name': 'news',
        'description': 'Get latest news',
        'category': 'information',
        'triggers': ['news', 'headlines', 'latest'],
      },
      {
        'name': 'translate',
        'description': 'Translate text between languages',
        'category': 'utility',
        'triggers': ['translate', 'translation', 'meaning'],
      },
      {
        'name': 'calculator',
        'description': 'Perform calculations',
        'category': 'utility',
        'triggers': ['calculate', 'math', 'compute'],
      },
    ],
    'openclaw': [
      {
        'name': 'code_review',
        'description': 'Review code for issues',
        'category': 'development',
        'triggers': ['review', 'code review', 'check code'],
      },
      {
        'name': 'git_commit',
        'description': 'Create git commits',
        'category': 'development',
        'triggers': ['commit', 'git commit', 'save changes'],
      },
      {
        'name': 'file_organize',
        'description': 'Organize files in directories',
        'category': 'productivity',
        'triggers': ['organize', 'sort files', 'clean up'],
      },
      {
        'name': 'reminder',
        'description': 'Set reminders',
        'category': 'productivity',
        'triggers': ['remind', 'reminder', 'alarm'],
      },
      {
        'name': 'joke',
        'description': 'Tell a joke',
        'category': 'entertainment',
        'triggers': ['joke', 'funny', 'laugh'],
      },
    ],
  };

  // Add a skill
  void addSkill(Skill skill) {
    _skills.add(skill);
    _skillController.add(skill);
  }

  // Import skills from a source
  Future<void> importFromSource(String source) async {
    final sourceSkills = _skillSources[source];
    if (sourceSkills != null) {
      for (final skillData in sourceSkills) {
        final skill = Skill.create(
          name: skillData['name'],
          description: skillData['description'],
          category: skillData['category'],
          source: source,
          triggers: List<String>.from(skillData['triggers']),
        );
        addSkill(skill);
      }
    }
  }

  // Import from JSON
  Future<void> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      if (data is List) {
        for (final skillData in data) {
          final skill = Skill.create(
            name: skillData['name'],
            description: skillData['description'],
            category: skillData['category'] ?? 'general',
            source: 'imported',
            config: skillData['config'] ?? {},
            triggers: List<String>.from(skillData['triggers'] ?? []),
          );
          addSkill(skill);
        }
      }
    } catch (e) {
      throw Exception('Failed to import skills: $e');
    }
  }

  // Find matching skill for input
  Skill? findMatchingSkill(String input) {
    final lowerInput = input.toLowerCase();
    for (final skill in _skills) {
      for (final trigger in skill.triggers) {
        if (lowerInput.contains(trigger.toLowerCase())) {
          return skill;
        }
      }
    }
    return null;
  }

  // Update skill usage
  void updateUsage(String skillId) {
    final index = _skills.indexWhere((s) => s.id == skillId);
    if (index != -1) {
      _skills[index] = _skills[index].copyWith(
        lastUsed: DateTime.now(),
        usageCount: _skills[index].usageCount + 1,
      );
    }
  }

  // Remove skill
  void removeSkill(String skillId) {
    _skills.removeWhere((s) => s.id == skillId);
  }

  // Get skills by category
  List<Skill> getSkillsByCategory(String category) {
    return _skills.where((s) => s.category == category).toList();
  }

  // Get all categories
  List<String> getCategories() {
    return _skills.map((s) => s.category).toSet().toList();
  }

  // Self-improve: analyze usage and suggest new skills
  List<String> analyzeAndSuggest() {
    final suggestions = <String>[];
    final frequentTriggers = <String, int>{};

    for (final skill in _skills) {
      for (final trigger in skill.triggers) {
        frequentTriggers[trigger] = (frequentTriggers[trigger] ?? 0) + skill.usageCount;
      }
    }

    // Find unused triggers
    final unusedTriggers = frequentTriggers.entries
        .where((e) => e.value == 0)
        .map((e) => e.key)
        .toList();

    if (unusedTriggers.isNotEmpty) {
      suggestions.add('Consider removing unused triggers: ${unusedTriggers.join(', ')}');
    }

    return suggestions;
  }

  void dispose() {
    _skillController.close();
  }
}
