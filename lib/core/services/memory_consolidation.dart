import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:nextron_ai/core/memory_evolution.dart';
import 'package:nextron_ai/core/girlfriend_memory.dart';
import 'package:nextron_ai/core/models/consolidated_memory.dart';

class MemoryConsolidationService {
  static Database? _database;
  final MemoryEvolution _memoryEvolution;

  final StreamController<ConsolidatedMemory> _memoryStream =
      StreamController<ConsolidatedMemory>.broadcast();
  Stream<ConsolidatedMemory> get memoryStream => _memoryStream.stream;

  Timer? _consolidationTimer;
  bool _isConsolidating = false;

  MemoryConsolidationService({
    required MemoryEvolution memoryEvolution,
  }) : _memoryEvolution = memoryEvolution;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_memory.db');
    return await openDatabase(path, version: 3);
  }

  /// Start automatic consolidation (runs every 5 minutes)
  void startAutoConsolidation() {
    _consolidationTimer?.cancel();
    _consolidationTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => consolidateRecentMemories(),
    );
  }

  void stopAutoConsolidation() {
    _consolidationTimer?.cancel();
    _consolidationTimer = null;
  }

  /// Main consolidation entry point - analyzes recent messages and extracts facts
  Future<void> consolidateRecentMemories() async {
    if (_isConsolidating) return;
    _isConsolidating = true;

    try {
      // Get recent interactions from MemoryEvolution
      final interactions = await _memoryEvolution.getRecentInteractions(limit: 20);

      for (final interaction in interactions) {
        final userMessage = interaction['user_message'] as String? ?? '';
        final aiResponse = interaction['ai_response'] as String? ?? '';

        // Extract facts from user message
        final facts = _extractFacts(userMessage);
        for (final fact in facts) {
          await _processExtractedFact(fact, 'user_message');
        }

        // Extract facts from AI response (e.g., confirmed information)
        final confirmedFacts = _extractConfirmedFacts(aiResponse);
        for (final fact in confirmedFacts) {
          await _processExtractedFact(fact, 'ai_confirmed');
        }
      }

      // Promote from GirlfriendMemory
      await _promoteFromGirlfriendMemory();

      // Reinforce existing memories
      await _reinforceExistingMemories();

      // Update user profile
      await _updateUserProfile();
    } catch (e) {
      // Silently handle errors
    } finally {
      _isConsolidating = false;
    }
  }

  /// Process a single user message (called from AppProvider)
  Future<void> processMessage(String userMessage, String aiResponse) async {
    try {
      final facts = _extractFacts(userMessage);
      for (final fact in facts) {
        await _processExtractedFact(fact, 'user_message');
      }

      final confirmedFacts = _extractConfirmedFacts(aiResponse);
      for (final fact in confirmedFacts) {
        await _processExtractedFact(fact, 'ai_confirmed');
      }
    } catch (e) {}
  }

  /// Extract high-value facts from a message
  List<ExtractedFact> _extractFacts(String message) {
    final facts = <ExtractedFact>[];
    // Name patterns
    final namePatterns = [
      RegExp(r"my name is (\w+)", caseSensitive: false),
      RegExp(r"i'm (\w+)", caseSensitive: false),
      RegExp(r"i am (\w+)", caseSensitive: false),
      RegExp(r"call me (\w+)", caseSensitive: false),
      RegExp(r"this is (\w+)", caseSensitive: false),
    ];
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final name = match.group(1)!;
        if (!_isCommonWord(name)) {
          facts.add(ExtractedFact(
            content: name,
            category: MemoryCategory.name,
            importance: 90,
            confidence: 0.8,
            key: 'user_name',
          ));
        }
      }
    }

    // Project patterns
    final projectPatterns = [
      RegExp(r"(?:building|working on|developing|created|made) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:my project|project) (?:is |called |named )(.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:app|website|software|tool) (?:called |named )(.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in projectPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final project = match.group(1)!.trim();
        if (project.length > 2 && project.length < 100) {
          facts.add(ExtractedFact(
            content: project,
            category: MemoryCategory.project,
            importance: 80,
            confidence: 0.7,
            key: 'project_${project.toLowerCase()}',
          ));
        }
      }
    }

    // Goal patterns
    final goalPatterns = [
      RegExp(r"(?:want to|goal is|trying to|plan to|aim to) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:i need to|i should|i must) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in goalPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final goal = match.group(1)!.trim();
        if (goal.length > 3 && goal.length < 150) {
          facts.add(ExtractedFact(
            content: goal,
            category: MemoryCategory.goal,
            importance: 75,
            confidence: 0.6,
            key: 'goal_${goal.hashCode}',
          ));
        }
      }
    }

    // Skill patterns
    final skillPatterns = [
      RegExp(r"(?:i know|i'm good at|i can|i'm skilled in|expertise in) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:my skills?|programming languages?) (?:are |include |is )(.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in skillPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final skill = match.group(1)!.trim();
        if (skill.length > 2 && skill.length < 100) {
          facts.add(ExtractedFact(
            content: skill,
            category: MemoryCategory.skill,
            importance: 70,
            confidence: 0.6,
            key: 'skill_${skill.toLowerCase()}',
          ));
        }
      }
    }

    // Interest patterns
    final interestPatterns = [
      RegExp(r"(?:i like|i love|i enjoy|i'm interested in|passionate about) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:favorite|favourite) (.+?)(?: is | are |: )(.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in interestPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final interest = match.group(1)!.trim();
        if (interest.length > 2 && interest.length < 100) {
          facts.add(ExtractedFact(
            content: interest,
            category: MemoryCategory.interest,
            importance: 60,
            confidence: 0.5,
            key: 'interest_${interest.toLowerCase()}',
          ));
        }
      }
    }

    // Preference patterns
    final prefPatterns = [
      RegExp(r"(?:i prefer|i want|i like my|i need) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:don't like|dislike|hate) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in prefPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final pref = match.group(1)!.trim();
        if (pref.length > 2 && pref.length < 100) {
          facts.add(ExtractedFact(
            content: pref,
            category: MemoryCategory.preference,
            importance: 65,
            confidence: 0.5,
            key: 'pref_${pref.toLowerCase()}',
          ));
        }
      }
    }

    // Relationship patterns
    final relPatterns = [
      RegExp(r"(?:my (?:friend|colleague|partner|wife|husband|brother|sister|mom|dad|mother|father|son|daughter)) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in relPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final rel = match.group(0)!.trim();
        facts.add(ExtractedFact(
          content: rel,
          category: MemoryCategory.relationship,
          importance: 70,
          confidence: 0.6,
          key: 'rel_${rel.hashCode}',
        ));
      }
    }

    // Date patterns
    final datePatterns = [
      RegExp(r"(?:birthday|anniversary|date) (?:is |: )(.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
      RegExp(r"(?:on|at) (\d{1,2}(?:st|nd|rd|th)? (?:of )?(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*)", caseSensitive: false),
    ];
    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final date = match.group(1)!.trim();
        facts.add(ExtractedFact(
          content: date,
          category: MemoryCategory.date,
          importance: 75,
          confidence: 0.7,
          key: 'date_${date.hashCode}',
        ));
      }
    }

    // Plan patterns
    final planPatterns = [
      RegExp(r"(?:going to|planning to|will|shall) (.+?)(?:\.|,|!|\?|$)", caseSensitive: false),
    ];
    for (final pattern in planPatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final plan = match.group(1)!.trim();
        if (plan.length > 3 && plan.length < 150 && !_isTemporaryPhrase(plan)) {
          facts.add(ExtractedFact(
            content: plan,
            category: MemoryCategory.plan,
            importance: 65,
            confidence: 0.5,
            key: 'plan_${plan.hashCode}',
          ));
        }
      }
    }

    return facts;
  }

  /// Extract confirmed facts from AI response
  List<ExtractedFact> _extractConfirmedFacts(String response) {
    final facts = <ExtractedFact>[];
    final lower = response.toLowerCase();

    // If AI confirms user's name
    if (lower.contains('nice to meet you') ||
        lower.contains('hello') && lower.contains('name')) {
      // This is a response to a name introduction - the user fact is already captured
    }

    // If AI acknowledges a project
    if (lower.contains('great project') ||
        lower.contains('sounds like') ||
        lower.contains('that\'s impressive')) {
      // AI confirmed the project is real
    }

    return facts;
  }

  /// Process an extracted fact - check for duplicates, score, and store
  Future<void> _processExtractedFact(
      ExtractedFact fact, String source) async {
    final db = await database;

    // Check for existing similar memory
    final existing = await _findSimilarMemory(fact.content, fact.category);

    if (existing != null) {
      // Reinforce existing memory instead of creating duplicate
      await _reinforceMemory(existing['id'] as String);
      return;
    }

    // Create new consolidated memory
    final memory = ConsolidatedMemory.create(
      content: fact.content,
      category: fact.category,
      importanceScore: fact.importance,
      confidenceScore: fact.confidence,
      source: source,
      metadata: {'key': fact.key},
    );

    await db.insert('consolidated_memories', memory.toMap());
    _memoryStream.add(memory);
  }

  /// Find similar memory using FTS
  Future<Map<String, dynamic>?> _findSimilarMemory(
      String content, MemoryCategory category) async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT cm.* FROM consolidated_memories cm
        JOIN consolidated_memories_fts fts ON cm.rowid = fts.rowid
        WHERE consolidated_memories_fts MATCH ?
        AND cm.category = ?
        LIMIT 1
      ''', [content, category.name]);

      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (_) {}

    // Fallback: keyword similarity
    try {
      final db = await database;
      final words = content.toLowerCase().split(RegExp(r'\s+'));
      final results = await db.query(
        'consolidated_memories',
        where: 'category = ?',
        whereArgs: [category.name],
      );

      for (final row in results) {
        final existingContent = (row['content'] as String).toLowerCase();
        final existingWords = existingContent.split(RegExp(r'\s+'));
        final overlap = words.where((w) => existingWords.contains(w)).length;
        if (overlap >= words.length * 0.6) {
          return row;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Reinforce an existing memory
  Future<void> _reinforceMemory(String memoryId) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE consolidated_memories
        SET reinforcement_count = reinforcement_count + 1,
            confidence_score = MIN(1.0, confidence_score + 0.05),
            importance_score = MIN(100, importance_score + 2),
            last_reinforced_at = ?,
            updated_at = ?
        WHERE id = ?
      ''', [
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        memoryId,
      ]);
    } catch (_) {}
  }

  /// Reinforce memories that appear repeatedly
  Future<void> _reinforceExistingMemories() async {
    try {
      final db = await database;
      final interactions = await _memoryEvolution.getRecentInteractions(limit: 10);

      for (final interaction in interactions) {
        final message = (interaction['user_message'] as String? ?? '').toLowerCase();

        // Find matching consolidated memories
        final memories = await db.query('consolidated_memories');
        for (final mem in memories) {
          final content = (mem['content'] as String).toLowerCase();
          final words = content.split(RegExp(r'\s+'));
          final messageWords = message.split(RegExp(r'\s+'));
          final overlap = words.where((w) => messageWords.contains(w)).length;

          if (overlap >= words.length * 0.5) {
            await _reinforceMemory(mem['id'] as String);
          }
        }
      }
    } catch (_) {}
  }

  /// Promote memories from GirlfriendMemory to consolidated store
  Future<void> _promoteFromGirlfriendMemory() async {
    try {
      final db = await database;

      // Promote user name
      final userName = GirlfriendMemory.getUserName();
      if (userName != null && userName.isNotEmpty) {
        final existing = await _findSimilarMemory(userName, MemoryCategory.name);
        if (existing == null) {
          final memory = ConsolidatedMemory.create(
            content: userName,
            category: MemoryCategory.name,
            importanceScore: 90,
            confidenceScore: 0.9,
            source: 'girlfriend_memory',
            metadata: {'key': 'user_name'},
          );
          await db.insert('consolidated_memories', memory.toMap());
        }
      }

      // Promote birthday
      final birthday = GirlfriendMemory.getBirthday();
      if (birthday != null && birthday.isNotEmpty) {
        final existing = await _findSimilarMemory(birthday, MemoryCategory.date);
        if (existing == null) {
          final memory = ConsolidatedMemory.create(
            content: 'Birthday: $birthday',
            category: MemoryCategory.date,
            importanceScore: 85,
            confidenceScore: 0.9,
            source: 'girlfriend_memory',
            metadata: {'key': 'birthday'},
          );
          await db.insert('consolidated_memories', memory.toMap());
        }
      }

      // Promote favorites
      final allFacts = GirlfriendMemory.getAllFacts();
      for (final fact in allFacts) {
        if (fact.importance >= 5) {
          final category = _mapGirlfriendCategory(fact.category);
          final existing = await _findSimilarMemory(fact.value, category);
          if (existing == null) {
            final memory = ConsolidatedMemory.create(
              content: fact.value,
              category: category,
              importanceScore: (fact.importance * 10).clamp(50, 100),
              confidenceScore: 0.7,
              source: 'girlfriend_memory',
              metadata: {'key': fact.key, 'gfCategory': fact.category},
            );
            await db.insert('consolidated_memories', memory.toMap());
          }
        }
      }
    } catch (_) {}
  }

  /// Update user profile from consolidated memories
  Future<void> _updateUserProfile() async {
    try {
      final db = await database;
      final memories = await db.query(
        'consolidated_memories',
        orderBy: 'importance_score DESC, confidence_score DESC',
      );

      final profileFields = <String, String>{};

      for (final mem in memories) {
        final content = mem['content'] as String;
        final category = mem['category'] as String;
        final confidence = (mem['confidence_score'] as num).toDouble();

        if (confidence < 0.4) continue;

        switch (category) {
          case 'name':
            profileFields['name'] = content;
            break;
          case 'project':
            final existing = profileFields['projects'] ?? '';
            if (!existing.contains(content)) {
              profileFields['projects'] =
                  existing.isEmpty ? content : '$existing, $content';
            }
            break;
          case 'goal':
            final existing = profileFields['goals'] ?? '';
            if (!existing.contains(content)) {
              profileFields['goals'] =
                  existing.isEmpty ? content : '$existing, $content';
            }
            break;
          case 'skill':
            final existing = profileFields['skills'] ?? '';
            if (!existing.contains(content)) {
              profileFields['skills'] =
                  existing.isEmpty ? content : '$existing, $content';
            }
            break;
          case 'interest':
            final existing = profileFields['interests'] ?? '';
            if (!existing.contains(content)) {
              profileFields['interests'] =
                  existing.isEmpty ? content : '$existing, $content';
            }
            break;
          case 'preference':
            final existing = profileFields['preferences'] ?? '';
            if (!existing.contains(content)) {
              profileFields['preferences'] =
                  existing.isEmpty ? content : '$existing, $content';
            }
            break;
          case 'date':
            final existing = profileFields['important_dates'] ?? '';
            if (!existing.contains(content)) {
              profileFields['important_dates'] =
                  existing.isEmpty ? content : '$existing, $content';
            }
            break;
        }
      }

      // Save profile fields
      final now = DateTime.now().toIso8601String();
      for (final entry in profileFields.entries) {
        await db.rawInsert('''
          INSERT OR REPLACE INTO user_profile (id, field_name, field_value, confidence, source, created_at, updated_at)
          VALUES (?, ?, ?, 0.8, 'auto_consolidated', ?, ?)
        ''', [
          'profile_${entry.key}',
          entry.key,
          entry.value,
          now,
          now,
        ]);
      }
    } catch (_) {}
  }

  /// Get consolidated memory context for AI
  Future<String> getMemoryContext() async {
    try {
      final db = await database;
      final buffer = StringBuffer();

      // Get user profile
      final profile = await db.query(
        'user_profile',
        orderBy: 'field_name',
      );

      if (profile.isNotEmpty) {
        buffer.writeln('USER PROFILE:');
        for (final field in profile) {
          buffer.writeln(
              '  ${field['field_name']}: ${field['field_value']}');
        }
        buffer.writeln();
      }

      // Get top important memories
      final topMemories = await db.query(
        'consolidated_memories',
        orderBy: 'importance_score DESC, confidence_score DESC',
        limit: 20,
      );

      if (topMemories.isNotEmpty) {
        buffer.writeln('IMPORTANT MEMORIES:');
        for (final mem in topMemories) {
          final content = mem['content'];
          final category = mem['category'];
          final importance = mem['importance_score'];
          buffer.writeln('  [$category] $content (importance: $importance)');
        }
      }

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Get top memories relevant to a query
  Future<List<ConsolidatedMemory>> recallMemories(
      String query, {int limit = 10}) async {
    try {
      final db = await database;

      // FTS search
      try {
        final results = await db.rawQuery('''
          SELECT cm.* FROM consolidated_memories cm
          JOIN consolidated_memories_fts fts ON cm.rowid = fts.rowid
          WHERE consolidated_memories_fts MATCH ?
          ORDER BY rank
          LIMIT ?
        ''', [query, limit]);

        return results.map((m) => ConsolidatedMemory.fromMap(m)).toList();
      } catch (_) {}

      // Fallback: keyword search
      final words = query.toLowerCase().split(RegExp(r'\s+'));
      final results = await db.query('consolidated_memories');
      final scored = <MapEntry<ConsolidatedMemory, double>>[];

      for (final row in results) {
        final mem = ConsolidatedMemory.fromMap(row);
        final content = mem.content.toLowerCase();
        var score = 0.0;

        for (final word in words) {
          if (content.contains(word)) {
            score += 1.0;
          }
        }

        score *= mem.confidenceScore;

        if (score > 0) {
          scored.add(MapEntry(mem, score));
        }
      }

      scored.sort((a, b) => b.value.compareTo(a.value));
      return scored.take(limit).map((e) => e.key).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get all consolidated memories
  Future<List<ConsolidatedMemory>> getAllMemories({
    String? category,
    int limit = 100,
  }) async {
    try {
      final db = await database;
      final where = category != null ? 'category = ?' : null;
      final whereArgs = category != null ? [category] : null;

      final results = await db.query(
        'consolidated_memories',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'importance_score DESC',
        limit: limit,
      );

      return results.map((m) => ConsolidatedMemory.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get user profile
  Future<Map<String, String>> getUserProfile() async {
    try {
      final db = await database;
      final results = await db.query('user_profile');

      final profile = <String, String>{};
      for (final row in results) {
        profile[row['field_name'] as String] = row['field_value'] as String;
      }
      return profile;
    } catch (_) {
      return {};
    }
  }

  /// Manually add a memory
  Future<void> addMemory({
    required String content,
    required MemoryCategory category,
    int importance = 50,
    double confidence = 0.5,
  }) async {
    final db = await database;
    final memory = ConsolidatedMemory.create(
      content: content,
      category: category,
      importanceScore: importance,
      confidenceScore: confidence,
      source: 'manual',
    );
    await db.insert('consolidated_memories', memory.toMap());
    _memoryStream.add(memory);
    await _updateUserProfile();
  }

  /// Delete a consolidated memory
  Future<void> deleteMemory(String id) async {
    try {
      final db = await database;
      await db.delete('consolidated_memories', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// Get stats
  Future<Map<String, dynamic>> getStats() async {
    try {
      final db = await database;
      final total = await db.rawQuery('SELECT COUNT(*) as c FROM consolidated_memories');
      final byCategory = await db.rawQuery(
          'SELECT category, COUNT(*) as c FROM consolidated_memories GROUP BY category');
      final avgImportance = await db.rawQuery(
          'SELECT AVG(importance_score) as avg FROM consolidated_memories');
      final avgConfidence = await db.rawQuery(
          'SELECT AVG(confidence_score) as avg FROM consolidated_memories');

      return {
        'total_memories': total.first['c'] ?? 0,
        'by_category': {for (final r in byCategory) r['category']: r['c']},
        'avg_importance': (avgImportance.first['avg'] as num?)?.toDouble() ?? 0,
        'avg_confidence': (avgConfidence.first['avg'] as num?)?.toDouble() ?? 0,
      };
    } catch (_) {
      return {'total_memories': 0};
    }
  }

  bool _isCommonWord(String word) {
    final common = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'can', 'shall', 'to', 'of', 'in', 'for',
      'on', 'with', 'at', 'by', 'from', 'as', 'into', 'about', 'just',
      'like', 'than', 'then', 'so', 'but', 'and', 'or', 'if', 'this',
      'that', 'it', 'he', 'she', 'we', 'they', 'you', 'i', 'me', 'my',
      'your', 'his', 'her', 'our', 'its', 'their', 'what', 'which',
      'who', 'when', 'where', 'how', 'all', 'each', 'every', 'both',
      'few', 'more', 'most', 'other', 'some', 'such', 'no', 'not',
      'only', 'own', 'same', 'too', 'very', 'also', 'now',
    };
    return common.contains(word.toLowerCase());
  }

  bool _isTemporaryPhrase(String phrase) {
    final temporary = [
      'today', 'tomorrow', 'yesterday', 'now', 'right now',
      'later', 'soon', 'this week', 'this month',
    ];
    return temporary.any((t) => phrase.toLowerCase().contains(t));
  }

  MemoryCategory _mapGirlfriendCategory(String gfCategory) {
    switch (gfCategory) {
      case 'user_profile':
        return MemoryCategory.name;
      case 'favorites':
        return MemoryCategory.preference;
      case 'shared_experiences':
        return MemoryCategory.daily;
      case 'emotions':
        return MemoryCategory.emotional;
      case 'special_dates':
        return MemoryCategory.date;
      case 'daily_life':
        return MemoryCategory.daily;
      default:
        return MemoryCategory.fact;
    }
  }

  void dispose() {
    _consolidationTimer?.cancel();
    _memoryStream.close();
  }
}

/// Internal fact extraction result
class ExtractedFact {
  final String content;
  final MemoryCategory category;
  final int importance;
  final double confidence;
  final String key;

  ExtractedFact({
    required this.content,
    required this.category,
    required this.importance,
    required this.confidence,
    required this.key,
  });
}
