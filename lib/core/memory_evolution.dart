import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MoodRecord {
  final String emotion;
  final double confidence;
  final String context;
  final DateTime timestamp;

  MoodRecord({
    required this.emotion,
    required this.confidence,
    required this.context,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'emotion': emotion,
    'confidence': confidence,
    'context': context,
    'timestamp': timestamp.toIso8601String(),
  };
}

class MemoryEvolution {
  static Database? _database;
  static const _dbName = 'nextron_memory_evolution.db';

  static const Map<String, String> _emotionCompanions = {
    'happy': 'sad',
    'sad': 'happy',
    'angry': 'calm',
    'anxious': 'reassured',
    'excited': 'calm',
    'frustrated': 'patience',
    'romantic': 'love',
    'tired': 'rest',
    'neutral': 'neutral',
  };

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE interactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_message TEXT NOT NULL,
            ai_response TEXT NOT NULL,
            tools_used TEXT,
            success INTEGER DEFAULT 1,
            timestamp TEXT NOT NULL,
            context TEXT,
            emotion TEXT,
            emotion_confidence REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE learned_patterns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pattern_type TEXT NOT NULL,
            pattern_key TEXT NOT NULL,
            pattern_value TEXT NOT NULL,
            confidence REAL DEFAULT 0.5,
            occurrences INTEGER DEFAULT 1,
            last_seen TEXT NOT NULL,
            UNIQUE(pattern_type, pattern_key)
          )
        ''');

        await db.execute('''
          CREATE TABLE user_preferences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            learned_from TEXT,
            confidence REAL DEFAULT 0.5,
            updated_at TEXT NOT NULL,
            UNIQUE(category, key)
          )
        ''');

        await db.execute('''
          CREATE TABLE personality_traits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trait_name TEXT NOT NULL UNIQUE,
            trait_value TEXT NOT NULL,
            source TEXT DEFAULT 'default',
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE emotion_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            emotion TEXT NOT NULL,
            confidence REAL NOT NULL,
            intensity TEXT,
            context TEXT,
            triggers TEXT,
            timestamp TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE mood_trends (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            dominant_emotion TEXT,
            mood_score REAL,
            summary TEXT,
            UNIQUE(date)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS emotion_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              emotion TEXT NOT NULL,
              confidence REAL NOT NULL,
              intensity TEXT,
              context TEXT,
              triggers TEXT,
              timestamp TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS mood_trends (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              dominant_emotion TEXT,
              mood_score REAL,
              summary TEXT,
              UNIQUE(date)
            )
          ''');
          await db.execute('ALTER TABLE interactions ADD COLUMN emotion TEXT');
          await db.execute('ALTER TABLE interactions ADD COLUMN emotion_confidence REAL');
        }
      },
    );
  }

  Future<void> recordEmotion({
    required String emotion,
    required double confidence,
    String intensity = 'medium',
    String context = '',
    List<String> triggers = const [],
  }) async {
    final db = await database;
    final now = DateTime.now();
    
    await db.insert('emotion_history', {
      'emotion': emotion,
      'confidence': confidence,
      'intensity': intensity,
      'context': context,
      'triggers': jsonEncode(triggers),
      'timestamp': now.toIso8601String(),
    });

    // Update daily mood trend
    final today = now.toIso8601String().split('T')[0];
    final todayEmotions = await db.query(
      'emotion_history',
      where: "timestamp LIKE ?",
      whereArgs: ['$today%'],
    );

    if (todayEmotions.isNotEmpty) {
      final emotionCounts = <String, int>{};
      for (final e in todayEmotions) {
        final em = e['emotion'] as String;
        emotionCounts[em] = (emotionCounts[em] ?? 0) + 1;
      }
      
      final dominant = emotionCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final avgConfidence = todayEmotions
          .map((e) => e['confidence'] as double)
          .reduce((a, b) => a + b) / todayEmotions.length;

      await db.insert(
        'mood_trends',
        {
          'date': today,
          'dominant_emotion': dominant.first.key,
          'mood_score': avgConfidence,
          'summary': emotionCounts.entries.map((e) => '${e.key}:${e.value}').join(', '),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<MoodRecord>> getRecentMoods({int limit = 5}) async {
    final db = await database;
    final rows = await db.query(
      'emotion_history',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((r) => MoodRecord(
      emotion: r['emotion'] as String,
      confidence: r['confidence'] as double,
      context: r['context'] as String? ?? '',
      timestamp: DateTime.parse(r['timestamp'] as String),
    )).toList();
  }

  Future<String> getCurrentMoodContext() async {
    final recent = await getRecentMoods(limit: 3);
    if (recent.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('RECENT EMOTIONS:');
    for (final mood in recent) {
      buffer.writeln('  - ${mood.emotion} (${mood.confidence.toStringAsFixed(2)}) at ${mood.timestamp.hour}:${mood.timestamp.minute}');
    }

    final currentMood = recent.first;
    final companion = _emotionCompanions[currentMood.emotion] ?? 'supportive';
    buffer.writeln('Current mood: ${currentMood.emotion}');
    buffer.writeln('Recommended response tone: $companion');

    return buffer.toString();
  }

  Future<Map<String, int>> getMoodDistribution({int days = 7}) async {
    final db = await database;
    final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query(
      'emotion_history',
      where: 'timestamp > ?',
      whereArgs: [since],
    );

    final distribution = <String, int>{};
    for (final row in rows) {
      final emotion = row['emotion'] as String;
      distribution[emotion] = (distribution[emotion] ?? 0) + 1;
    }
    return distribution;
  }

  // Record an interaction
  Future<void> recordInteraction({
    required String userMessage,
    required String aiResponse,
    List<String>? toolsUsed,
    bool success = true,
    String? context,
    String? emotion,
    double? emotionConfidence,
  }) async {
    final db = await database;
    await db.insert('interactions', {
      'user_message': userMessage,
      'ai_response': aiResponse,
      'tools_used': toolsUsed != null ? jsonEncode(toolsUsed) : null,
      'success': success ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
      'context': context,
      'emotion': emotion,
      'emotion_confidence': emotionConfidence,
    });

    // Analyze and learn from this interaction
    await _analyzeInteraction(userMessage, aiResponse, toolsUsed, success);
  }

  // Analyze interaction and learn patterns
  Future<void> _analyzeInteraction(
    String userMessage,
    String aiResponse,
    List<String>? toolsUsed,
    bool success,
  ) async {
    final lowerMessage = userMessage.toLowerCase();

    // Learn language preference
    if (lowerMessage.contains('hindi') || lowerMessage.contains('hinglish')) {
      await _updatePreference('communication', 'language', 'hinglish', 'interaction');
    } else if (lowerMessage.contains('english')) {
      await _updatePreference('communication', 'language', 'english', 'interaction');
    }

    // Learn topic interests
    final topics = _extractTopics(lowerMessage);
    for (final topic in topics) {
      await _updatePattern('topic_interest', topic, 'interaction');
    }

    // Learn time patterns
    final hour = DateTime.now().hour;
    if (hour >= 9 && hour <= 12) {
      await _updatePattern('active_time', 'morning', 'interaction');
    } else if (hour >= 12 && hour <= 17) {
      await _updatePattern('active_time', 'afternoon', 'interaction');
    } else if (hour >= 17 && hour <= 21) {
      await _updatePattern('active_time', 'evening', 'interaction');
    } else {
      await _updatePattern('active_time', 'night', 'interaction');
    }

    // Learn tool preferences
    if (toolsUsed != null) {
      for (final tool in toolsUsed) {
        await _updatePattern('tool_preference', tool, 'interaction');
      }
    }

    // Learn conversation style
    if (lowerMessage.contains('quick') || lowerMessage.contains('short')) {
      await _updatePreference('communication', 'response_length', 'short', 'interaction');
    } else if (lowerMessage.contains('detail') || lowerMessage.contains('explain')) {
      await _updatePreference('communication', 'response_length', 'detailed', 'interaction');
    }
  }

  List<String> _extractTopics(String message) {
    final topics = <String>[];
    final topicKeywords = {
      'code': ['code', 'program', 'debug', 'function', 'class'],
      'file': ['file', 'folder', 'document', 'read', 'write'],
      'email': ['email', 'mail', 'inbox', 'send'],
      'calendar': ['calendar', 'event', 'meeting', 'schedule'],
      'social': ['facebook', 'instagram', 'telegram', 'discord'],
      'weather': ['weather', 'temperature', 'forecast'],
      'news': ['news', 'update', 'latest', 'trending'],
    };

    for (final entry in topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (message.contains(keyword)) {
          topics.add(entry.key);
          break;
        }
      }
    }

    return topics;
  }

  // Update a learned pattern
  Future<void> _updatePattern(String type, String key, String source) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'learned_patterns',
      where: 'pattern_type = ? AND pattern_key = ?',
      whereArgs: [type, key],
    );

    if (existing.isNotEmpty) {
      final count = (existing.first['occurrences'] as int) + 1;
      final confidence = (count / (count + 2)).clamp(0.0, 1.0);

      await db.update(
        'learned_patterns',
        {
          'occurrences': count,
          'confidence': confidence,
          'last_seen': now,
        },
        where: 'pattern_type = ? AND pattern_key = ?',
        whereArgs: [type, key],
      );
    } else {
      await db.insert('learned_patterns', {
        'pattern_type': type,
        'pattern_key': key,
        'pattern_value': key,
        'confidence': 0.3,
        'occurrences': 1,
        'last_seen': now,
      });
    }
  }

  // Update a user preference
  Future<void> _updatePreference(String category, String key, String value, String source) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'user_preferences',
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
    );

    if (existing.isNotEmpty) {
      final confidence = ((existing.first['confidence'] as double) + 0.1).clamp(0.0, 1.0);
      await db.update(
        'user_preferences',
        {
          'value': value,
          'confidence': confidence,
          'learned_from': source,
          'updated_at': now,
        },
        where: 'category = ? AND key = ?',
        whereArgs: [category, key],
      );
    } else {
      await db.insert('user_preferences', {
        'category': category,
        'key': key,
        'value': value,
        'learned_from': source,
        'confidence': 0.3,
        'updated_at': now,
      });
    }
  }

  // Get learned preferences
  Future<Map<String, String>> getPreferences() async {
    final db = await database;
    final results = await db.query('user_preferences');
    final prefs = <String, String>{};
    for (final row in results) {
      final key = '${row['category']}_${row['key']}';
      prefs[key] = row['value'] as String;
    }
    return prefs;
  }

  // Get a specific preference
  Future<String?> getPreference(String category, String key) async {
    final db = await database;
    final results = await db.query(
      'user_preferences',
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
    );
    if (results.isNotEmpty) {
      return results.first['value'] as String;
    }
    return null;
  }

  // Get top patterns by type
  Future<List<Map<String, dynamic>>> getTopPatterns(String type, {int limit = 5}) async {
    final db = await database;
    return await db.query(
      'learned_patterns',
      where: 'pattern_type = ?',
      whereArgs: [type],
      orderBy: 'confidence DESC, occurrences DESC',
      limit: limit,
    );
  }

  // Get conversation context for AI
  Future<String> getConversationContext() async {
    final prefs = await getPreferences();
    final topTopics = await getTopPatterns('topic_interest', limit: 3);
    final topTools = await getTopPatterns('tool_preference', limit: 5);
    final activeTime = await getTopPatterns('active_time', limit: 1);
    final moodContext = await getCurrentMoodContext();

    final context = StringBuffer();
    context.writeln('LEARNED USER PROFILE:');
    context.writeln('---');

    if (prefs.isNotEmpty) {
      context.writeln('Preferences:');
      for (final entry in prefs.entries) {
        context.writeln('  - ${entry.key}: ${entry.value}');
      }
    }

    if (topTopics.isNotEmpty) {
      context.writeln('Interests: ${topTopics.map((t) => t['pattern_key']).join(', ')}');
    }

    if (topTools.isNotEmpty) {
      context.writeln('Frequent Tools: ${topTools.map((t) => t['pattern_key']).join(', ')}');
    }

    if (activeTime.isNotEmpty) {
      context.writeln('Active Time: ${activeTime.first['pattern_key']}');
    }

    if (moodContext.isNotEmpty) {
      context.writeln(moodContext);
    }

    context.writeln('---');
    return context.toString();
  }

  // Get stats
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final interactionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM interactions'),
    );
    final patternCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM learned_patterns'),
    );
    final prefCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM user_preferences'),
    );
    final successRate = await db.rawQuery(
      'SELECT AVG(success) as rate FROM interactions',
    );

    return {
      'total_interactions': interactionCount ?? 0,
      'learned_patterns': patternCount ?? 0,
      'user_preferences': prefCount ?? 0,
      'success_rate': (successRate.first['rate'] as double?) ?? 0.0,
    };
  }

  // Get recent interactions for context
  Future<List<Map<String, dynamic>>> getRecentInteractions({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'interactions',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // Get interaction count
  Future<int> getInteractionCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM interactions'),
    ) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
