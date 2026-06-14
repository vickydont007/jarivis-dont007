import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MemorySearchResult {
  final String memoryId;
  final String content;
  final String category;
  final double score;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  MemorySearchResult({
    required this.memoryId,
    required this.content,
    required this.category,
    required this.score,
    required this.createdAt,
    this.metadata = const {},
  });
}

class MemorySearch {
  static Database? _database;
  static const _dbName = 'nextron_memory.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(path, version: 1);
  }

  Future<List<MemorySearchResult>> search(String query, {int limit = 10, String? category}) async {
    final db = await database;

    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isEmpty) return [];

    final buffer = StringBuffer();
    final args = <dynamic>[];

    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' OR ');
      buffer.write('(LOWER(content) LIKE ? OR LOWER(tags) LIKE ?)');
      args.add('%${words[i]}%');
      args.add('%${words[i]}%');
    }

    String whereClause = buffer.toString();
    if (category != null) {
      whereClause = '($whereClause) AND type = ?';
      args.add(category);
    }

    final results = await db.query(
      'memories',
      where: whereClause,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit * 2,
    );

    final scored = results.map((row) {
      final content = (row['content'] as String? ?? '').toLowerCase();
      final tags = (row['tags'] as String? ?? '').toLowerCase();
      final score = _calculateScore(query, content, tags, words);
      return MemorySearchResult(
        memoryId: row['id'] as String,
        content: row['content'] as String? ?? '',
        category: row['type'] as String? ?? 'general',
        score: score,
        createdAt: DateTime.parse(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
        metadata: {
          'importance': row['importance'] ?? 5,
          'source': row['source'] ?? '',
        },
      );
    }).where((r) => r.score > 0).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  double _calculateScore(String query, String content, String tags, List<String> words) {
    double score = 0;
    final queryLower = query.toLowerCase();

    if (content.contains(queryLower)) score += 10;
    if (tags.contains(queryLower)) score += 8;

    for (final word in words) {
      if (content.contains(word)) score += 3;
      if (tags.contains(word)) score += 2;
    }

    final exactMatches = words.where((w) => content.contains(w)).length;
    score += exactMatches * 1.5;

    final contentWords = content.split(RegExp(r'\s+'));
    final overlap = words.where((w) => contentWords.any((cw) => cw.contains(w))).length;
    score += (overlap / words.length) * 5;

    return score;
  }

  Future<List<MemorySearchResult>> semanticSearch(String query, {int limit = 10}) async {
    return search(query, limit: limit);
  }

  Future<List<MemorySearchResult>> getRecentMemories({int limit = 20, String? category}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (category != null) {
      where = 'type = ?';
      whereArgs = [category];
    }
    final results = await db.query(
      'memories',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((row) => MemorySearchResult(
      memoryId: row['id'] as String,
      content: row['content'] as String? ?? '',
      category: row['type'] as String? ?? 'general',
      score: 1.0,
      createdAt: DateTime.parse(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
      metadata: {
        'importance': row['importance'] ?? 5,
        'source': row['source'] ?? '',
      },
    )).toList();
  }

  Future<List<MemorySearchResult>> getImportantMemories({int limit = 10, int minImportance = 7}) async {
    final db = await database;
    final results = await db.query(
      'memories',
      where: 'importance >= ?',
      whereArgs: [minImportance],
      orderBy: 'importance DESC, created_at DESC',
      limit: limit,
    );
    return results.map((row) => MemorySearchResult(
      memoryId: row['id'] as String,
      content: row['content'] as String? ?? '',
      category: row['type'] as String? ?? 'general',
      score: (row['importance'] as int? ?? 5) / 10.0,
      createdAt: DateTime.parse(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
      metadata: {
        'importance': row['importance'] ?? 5,
        'source': row['source'] ?? '',
      },
    )).toList();
  }

  String buildContextForAgent(String agentTask, {int maxTokens = 2000}) {
    return 'Use the memory system to search for relevant information before executing tasks.';
  }

  Future<List<String>> getContextForAgent(String agentTask, {int maxResults = 5}) async {
    final results = await search(agentTask, limit: maxResults);
    return results.map((r) => r.content).toList();
  }
}
