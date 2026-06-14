import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ExternalSource {
  final String id;
  final String type;
  final String title;
  final String content;
  final String source;
  final String? url;
  final DateTime ingestedAt;
  final List<String> tags;

  ExternalSource({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.source,
    this.url,
    required this.ingestedAt,
    this.tags = const [],
  });
}

class ExternalKnowledge {
  static Database? _database;
  static const _dbName = 'nextron_external_knowledge.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE external_sources(
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            source TEXT NOT NULL,
            url TEXT,
            ingested_at TEXT NOT NULL,
            tags TEXT DEFAULT '[]'
          )
        ''');
        // Full-text search index
        await db.execute('''
          CREATE VIRTUAL TABLE knowledge_fts USING fts5(
            title, content, tags, content='external_sources', content_rowid='rowid'
          )
        ''');
        // Triggers to keep FTS in sync
        await db.execute('''
          CREATE TRIGGER knowledge_ai AFTER INSERT ON external_sources BEGIN
            INSERT INTO knowledge_fts(rowid, title, content, tags)
            VALUES (new.rowid, new.title, new.content, new.tags);
          END
        ''');
      },
    );
  }

  Future<void> ingest({
    required String type,
    required String title,
    required String content,
    required String source,
    String? url,
    List<String> tags = const [],
  }) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert('external_sources', {
      'id': id,
      'type': type,
      'title': title,
      'content': content.length > 5000 ? content.substring(0, 5000) : content,
      'source': source,
      'url': url,
      'ingested_at': DateTime.now().toIso8601String(),
      'tags': jsonEncode(tags),
    });
  }

  Future<List<ExternalSource>> search(String query, {int limit = 20}) async {
    final db = await database;
    // FTS5 search
    try {
      final results = await db.rawQuery('''
        SELECT e.* FROM external_sources e
        JOIN knowledge_fts f ON e.rowid = f.rowid
        WHERE knowledge_fts MATCH ?
        ORDER BY rank
        LIMIT ?
      ''', [_escapeFtsQuery(query), limit]);

      return results.map(_sourceFromRow).toList();
    } catch (e) {
      // Fallback to LIKE search
      final results = await db.query(
        'external_sources',
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'ingested_at DESC',
        limit: limit,
      );
      return results.map(_sourceFromRow).toList();
    }
  }

  Future<List<ExternalSource>> getByType(String type, {int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'external_sources',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'ingested_at DESC',
      limit: limit,
    );
    return results.map(_sourceFromRow).toList();
  }

  Future<List<ExternalSource>> getRecent({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'external_sources',
      orderBy: 'ingested_at DESC',
      limit: limit,
    );
    return results.map(_sourceFromRow).toList();
  }

  Future<Map<String, int>> getIngestionStats() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT type, COUNT(*) as cnt FROM external_sources GROUP BY type',
    );
    final stats = <String, int>{};
    for (final row in results) {
      final type = row['type'] as String? ?? '';
      final cnt = row['cnt'] as int? ?? 0;
      if (type.isNotEmpty) stats[type] = cnt;
    }
    return stats;
  }

  ExternalSource _sourceFromRow(Map<String, dynamic> row) {
    List<String> tags = [];
    try {
      tags = List<String>.from(jsonDecode(row['tags'] as String? ?? '[]'));
    } catch (e) {
      tags = [];
    }

    return ExternalSource(
      id: row['id'] as String,
      type: row['type'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      source: row['source'] as String,
      url: row['url'] as String?,
      ingestedAt: DateTime.parse(row['ingested_at'] as String),
      tags: tags,
    );
  }

  String _escapeFtsQuery(String query) {
    return query
        .replaceAll('"', '')
        .replaceAll("'", "")
        .split(RegExp(r'\s+'))
        .map((w) => w.length > 2 ? '"$w"' : '')
        .where((w) => w.isNotEmpty)
        .join(' ');
  }
}
