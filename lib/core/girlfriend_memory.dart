import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RelationshipFact {
  final String category;
  final String key;
  final String value;
  final DateTime timestamp;
  final int importance;

  RelationshipFact({
    required this.category,
    required this.key,
    required this.value,
    required this.timestamp,
    this.importance = 5,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'key': key,
    'value': value,
    'timestamp': timestamp.toIso8601String(),
    'importance': importance,
  };

  factory RelationshipFact.fromJson(Map<String, dynamic> json) => RelationshipFact(
    category: json['category'] ?? '',
    key: json['key'] ?? '',
    value: json['value'] ?? '',
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    importance: json['importance'] ?? 5,
  );
}

class Milestone {
  final String type;
  final DateTime timestamp;
  final String description;

  Milestone({required this.type, required this.timestamp, required this.description});

  Map<String, dynamic> toJson() => {
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
  };

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    type: json['type'] ?? '',
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    description: json['description'] ?? '',
  );
}

class GirlfriendMemory {
  static const String _storageKey = 'nextron_girlfriend_memory';
  static const String _milestonesKey = 'nextron_relationship_milestones';
  static const String _firstConversationKey = 'nextron_first_conversation';

  static Map<String, List<RelationshipFact>> _facts = {};
  static List<Milestone> _milestones = [];
  static DateTime? _firstConversation;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load facts
    final factsJson = prefs.getString(_storageKey);
    if (factsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(factsJson);
        _facts = {};
        for (final entry in decoded.entries) {
          _facts[entry.key] = (entry.value as List)
              .map((f) => RelationshipFact.fromJson(f))
              .toList();
        }
      } catch (e) {
        _facts = {};
      }
    }

    // Load milestones
    final milestonesJson = prefs.getString(_milestonesKey);
    if (milestonesJson != null) {
      try {
        _milestones = (jsonDecode(milestonesJson) as List)
            .map((m) => Milestone.fromJson(m))
            .toList();
      } catch (e) {
        _milestones = [];
      }
    }

    // Load first conversation
    final firstConv = prefs.getString(_firstConversationKey);
    if (firstConv != null) {
      _firstConversation = DateTime.parse(firstConv);
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    
    final factsJson = jsonEncode(
      _facts.map((key, value) => MapEntry(key, value.map((f) => f.toJson()).toList())),
    );
    await prefs.setString(_storageKey, factsJson);
    
    final milestonesJson = jsonEncode(_milestones.map((m) => m.toJson()).toList());
    await prefs.setString(_milestonesKey, milestonesJson);
    
    if (_firstConversation != null) {
      await prefs.setString(_firstConversationKey, _firstConversation!.toIso8601String());
    }
  }

  static Future<void> rememberUserName(String name) async {
    await _addFact('user_profile', 'name', name);
  }

  static Future<void> rememberBirthday(String birthday) async {
    await _addFact('user_profile', 'birthday', birthday, importance: 8);
  }

  static Future<void> rememberFavorite(String key, String value) async {
    await _addFact('favorites', key, value, importance: 7);
  }

  static Future<void> rememberPromise(String promise) async {
    await _addFact('promises', DateTime.now().toIso8601String(), promise, importance: 9);
  }

  static Future<void> rememberSharedExperience(String experience) async {
    await _addFact('shared_experiences', DateTime.now().toIso8601String(), experience, importance: 6);
  }

  static Future<void> rememberEmotion(String emotion, String context) async {
    await _addFact('emotions', DateTime.now().toIso8601String(), '$emotion: $context', importance: 4);
  }

  static Future<void> rememberPhoto(String path, String context) async {
    await _addFact('shared_photos', DateTime.now().toIso8601String(), '$path | $context', importance: 6);
  }

  static List<RelationshipFact> getPhotos() {
    return getFactsByCategory('shared_photos');
  }

  static Future<void> rememberDailyUpdate(String update) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _addFact('daily_life', today, update, importance: 3);
  }

  static Future<void> rememberSpecialDate(String name, String date) async {
    await _addFact('special_dates', name, date, importance: 8);
  }

  static Future<void> _addFact(String category, String key, String value, {int importance = 5}) async {
    if (_facts[category] == null) {
      _facts[category] = [];
    }
    
    // Check if fact already exists, update if so
    final existingIndex = _facts[category]!.indexWhere((f) => f.key == key);
    if (existingIndex != -1) {
      _facts[category]![existingIndex] = RelationshipFact(
        category: category,
        key: key,
        value: value,
        timestamp: DateTime.now(),
        importance: importance,
      );
    } else {
      _facts[category]!.add(RelationshipFact(
        category: category,
        key: key,
        value: value,
        timestamp: DateTime.now(),
        importance: importance,
      ));
    }
    
    await _save();
  }

  static Future<void> addMilestone(String type, String description) async {
    _milestones.add(Milestone(
      type: type,
      timestamp: DateTime.now(),
      description: description,
    ));
    await _save();
  }

  static Future<void> recordFirstConversation() async {
    if (_firstConversation == null) {
      _firstConversation = DateTime.now();
      await _save();
    }
  }

  static List<RelationshipFact> getFactsByCategory(String category) {
    return _facts[category] ?? [];
  }

  static RelationshipFact? getFact(String category, String key) {
    final facts = _facts[category];
    if (facts == null) return null;
    try {
      return facts.firstWhere((f) => f.key == key);
    } catch (e) {
      return null;
    }
  }

  static List<RelationshipFact> getAllFacts() {
    final all = <RelationshipFact>[];
    for (final facts in _facts.values) {
      all.addAll(facts);
    }
    all.sort((a, b) => b.importance.compareTo(a.importance));
    return all;
  }

  static String? getUserName() {
    return getFact('user_profile', 'name')?.value;
  }

  static String? getBirthday() {
    return getFact('user_profile', 'birthday')?.value;
  }

  static List<RelationshipFact> getRecentEmotions({int limit = 5}) {
    final emotions = _facts['emotions'] ?? [];
    emotions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return emotions.take(limit).toList();
  }

  static List<Milestone> getMilestones() {
    return List.unmodifiable(_milestones);
  }

  static String getRelationshipContext() {
    final buffer = StringBuffer();
    final userName = getUserName();
    if (userName != null) {
      buffer.writeln('User name: $userName');
    }
    
    final birthday = getBirthday();
    if (birthday != null) {
      buffer.writeln('Birthday: $birthday');
    }

    final recentEmotions = getRecentEmotions(limit: 3);
    if (recentEmotions.isNotEmpty) {
      buffer.writeln('Recent emotions:');
      for (final e in recentEmotions) {
        buffer.writeln('  - ${e.value}');
      }
    }

    final promises = _facts['promises'] ?? [];
    if (promises.isNotEmpty) {
      buffer.writeln('Promises made:');
      for (final p in promises.take(3)) {
        buffer.writeln('  - ${p.value}');
      }
    }

    final experiences = _facts['shared_experiences'] ?? [];
    if (experiences.isNotEmpty) {
      buffer.writeln('Shared experiences:');
      for (final e in experiences.take(3)) {
        buffer.writeln('  - ${e.value}');
      }
    }

    final photos = _facts['shared_photos'] ?? [];
    if (photos.isNotEmpty) {
      buffer.writeln('Photos shared: ${photos.length} photos');
      for (final p in photos.take(2)) {
        buffer.writeln('  - ${p.value.split(' | ').last}');
      }
    }

    final milestones = getMilestones();
    if (milestones.isNotEmpty) {
      buffer.writeln('Milestones:');
      for (final m in milestones) {
        buffer.writeln('  - ${m.description}');
      }
    }

    if (_firstConversation != null) {
      final days = DateTime.now().difference(_firstConversation!).inDays;
      buffer.writeln('Together for: $days days');
    }

    return buffer.toString();
  }

  static Future<void> autoExtractFromMessage(String message) async {
    final lower = message.toLowerCase();

    // Extract name
    final namePatterns = [
      RegExp(r'my name is (\w+)', caseSensitive: false),
      RegExp(r'i am (\w+)', caseSensitive: false),
      RegExp(r"i'm (\w+)", caseSensitive: false),
      RegExp(r"mera naam (\w+)", caseSensitive: false),
    ];
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        await rememberUserName(match.group(1)!);
      }
    }

    // Extract birthday
    final birthdayPatterns = [
      RegExp(r'my birthday is (.+?)(?:\.|$)', caseSensitive: false),
      RegExp(r"i was born on (.+?)(?:\.|$)", caseSensitive: false),
      RegExp(r"birthday (.+?)(?:\.|$)", caseSensitive: false),
    ];
    for (final pattern in birthdayPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        await rememberBirthday(match.group(1)!.trim());
      }
    }

    // Extract promises
    if (lower.contains('promise') || lower.contains('vada') || lower.contains('waada')) {
      await rememberPromise(message);
    }

    // Track emotional moments
    if (lower.contains('miss you') || lower.contains('love you') || lower.contains('jaan')) {
      await rememberSharedExperience(message);
    }
  }
}
