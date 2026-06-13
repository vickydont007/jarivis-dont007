import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class ContextEntry {
  final String id;
  final String category;
  final String key;
  final String value;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final int importance;

  ContextEntry({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.importance = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'key': key,
      'value': value,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'importance': importance,
    };
  }

  factory ContextEntry.fromMap(Map<String, dynamic> map) {
    return ContextEntry(
      id: map['id'],
      category: map['category'],
      key: map['key'],
      value: map['value'],
      metadata: jsonDecode(map['metadata'] ?? '{}'),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']) : null,
      importance: map['importance'] ?? 0,
    );
  }
}

class ConversationContext {
  final String sessionId;
  final List<String> topics;
  final Map<String, dynamic> summary;
  final DateTime startTime;
  final DateTime lastActive;

  ConversationContext({
    required this.sessionId,
    required this.topics,
    required this.summary,
    required this.startTime,
    required this.lastActive,
  });
}

class ContextMemory {
  static Database? _database;
  final StreamController<ContextEntry> _contextController =
      StreamController<ContextEntry>.broadcast();

  Stream<ContextEntry> get contextStream => _contextController.stream;

  ContextMemory();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_context.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE context_entries(
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            metadata TEXT DEFAULT '{}',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            expires_at TEXT,
            importance INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_category ON context_entries(category)
        ''');

        await db.execute('''
          CREATE INDEX idx_key ON context_entries(key)
        ''');

        await db.execute('''
          CREATE INDEX idx_importance ON context_entries(importance DESC)
        ''');
      },
    );
  }

  Future<void> set({
    required String category,
    required String key,
    required String value,
    Map<String, dynamic> metadata = const {},
    Duration? ttl,
    int importance = 0,
  }) async {
    final db = await database;
    final now = DateTime.now();

    final entry = ContextEntry(
      id: const Uuid().v4(),
      category: category,
      key: key,
      value: value,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
      expiresAt: ttl != null ? now.add(ttl) : null,
      importance: importance,
    );

    await db.insert(
      'context_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _contextController.add(entry);
  }

  Future<String?> get(String category, String key) async {
    final db = await database;
    final results = await db.query(
      'context_entries',
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final entry = ContextEntry.fromMap(results.first);
    if (entry.expiresAt != null && entry.expiresAt!.isBefore(DateTime.now())) {
      await delete(category, key);
      return null;
    }

    return entry.value;
  }

  Future<Map<String, dynamic>> getMetadata(String category, String key) async {
    final db = await database;
    final results = await db.query(
      'context_entries',
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
      limit: 1,
    );

    if (results.isEmpty) return {};

    final entry = ContextEntry.fromMap(results.first);
    return entry.metadata;
  }

  Future<List<ContextEntry>> getByCategory(String category, {int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'context_entries',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'importance DESC, updated_at DESC',
      limit: limit,
    );

    return results
        .map((map) => ContextEntry.fromMap(map))
        .where((e) => e.expiresAt == null || e.expiresAt!.isAfter(DateTime.now()))
        .toList();
  }

  Future<List<ContextEntry>> search(String query, {int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'context_entries',
      where: 'key LIKE ? OR value LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'importance DESC, updated_at DESC',
      limit: limit,
    );

    return results
        .map((map) => ContextEntry.fromMap(map))
        .where((e) => e.expiresAt == null || e.expiresAt!.isAfter(DateTime.now()))
        .toList();
  }

  Future<List<ContextEntry>> getImportant({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'context_entries',
      where: 'importance > 0',
      orderBy: 'importance DESC, updated_at DESC',
      limit: limit,
    );

    return results
        .map((map) => ContextEntry.fromMap(map))
        .where((e) => e.expiresAt == null || e.expiresAt!.isAfter(DateTime.now()))
        .toList();
  }

  Future<void> update({
    required String category,
    required String key,
    String? value,
    Map<String, dynamic>? metadata,
    int? importance,
  }) async {
    final db = await database;
    final now = DateTime.now();

    final updates = <String, dynamic>{
      'updated_at': now.toIso8601String(),
    };

    if (value != null) updates['value'] = value;
    if (metadata != null) updates['metadata'] = jsonEncode(metadata);
    if (importance != null) updates['importance'] = importance;

    await db.update(
      'context_entries',
      updates,
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
    );
  }

  Future<bool> delete(String category, String key) async {
    final db = await database;
    final deleted = await db.delete(
      'context_entries',
      where: 'category = ? AND key = ?',
      whereArgs: [category, key],
    );
    return deleted > 0;
  }

  Future<void> deleteByCategory(String category) async {
    final db = await database;
    await db.delete(
      'context_entries',
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  Future<void> cleanup() async {
    final db = await database;
    await db.delete(
      'context_entries',
      where: 'expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final total = await db.rawQuery('SELECT COUNT(*) as count FROM context_entries');
    final categories = await db.rawQuery('SELECT DISTINCT category FROM context_entries');
    final important = await db.rawQuery(
      'SELECT COUNT(*) as count FROM context_entries WHERE importance > 0'
    );

    return {
      'total_entries': (total.first['count'] as int?) ?? 0,
      'categories': categories.map((r) => r['category'] as String).toList(),
      'important_entries': (important.first['count'] as int?) ?? 0,
    };
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('context_entries');
  }

  void dispose() {
    _contextController.close();
  }
}
