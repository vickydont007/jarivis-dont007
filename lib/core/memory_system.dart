import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class MemoryEntry {
  final String id;
  final String content;
  final String category;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemoryEntry({
    required this.id,
    required this.content,
    this.category = 'general',
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryEntry.create({
    required String content,
    String category = 'general',
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    return MemoryEntry(
      id: const Uuid().v4(),
      content: content,
      category: category,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'category': category,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MemoryEntry.fromMap(Map<String, dynamic> map) {
    return MemoryEntry(
      id: map['id'],
      content: map['content'],
      category: map['category'],
      metadata: jsonDecode(map['metadata']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class MemorySystem {
  static Database? _database;
  final StreamController<MemoryEntry> _memoryController =
      StreamController<MemoryEntry>.broadcast();

  Stream<MemoryEntry> get memoryStream => _memoryController.stream;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_memory.db');

    try {
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Create memories table
          await db.execute('''
            CREATE TABLE memories(
              id TEXT PRIMARY KEY,
              content TEXT NOT NULL,
              category TEXT DEFAULT 'general',
              metadata TEXT DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // Create FTS5 virtual table for full-text search
          await db.execute('''
            CREATE VIRTUAL TABLE memories_fts USING fts5(
              content,
              category,
              content='memories',
              content_rowid='rowid'
            )
          ''');

          // Create triggers to keep FTS in sync
          await db.execute('''
            CREATE TRIGGER memories_ai AFTER INSERT ON memories BEGIN
              INSERT INTO memories_fts(rowid, content, category)
              VALUES (new.rowid, new.content, new.category);
            END
          ''');

          await db.execute('''
            CREATE TRIGGER memories_ad AFTER DELETE ON memories BEGIN
              INSERT INTO memories_fts(memories_fts, rowid, content, category)
              VALUES('delete', old.rowid, old.content, old.category);
            END
          ''');

          await db.execute('''
            CREATE TRIGGER memories_au AFTER UPDATE ON memories BEGIN
              INSERT INTO memories_fts(memories_fts, rowid, content, category)
              VALUES('delete', old.rowid, old.content, old.category);
              INSERT INTO memories_fts(rowid, content, category)
              VALUES (new.rowid, new.content, new.category);
            END
          ''');
        },
      );
    } catch (e) {
      // Database corrupted — delete and recreate
      try {
        final dbFile = await getApplicationDocumentsDirectory();
        final dbPath = join(dbFile.path, 'nextron_memory.db');
        await deleteDatabase(dbPath);
      } catch (_) {}
      _database = null;
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE memories(
              id TEXT PRIMARY KEY,
              content TEXT NOT NULL,
              category TEXT DEFAULT 'general',
              metadata TEXT DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE VIRTUAL TABLE memories_fts USING fts5(
              content,
              category,
              content='memories',
              content_rowid='rowid'
            )
          ''');
          await db.execute('''
            CREATE TRIGGER memories_ai AFTER INSERT ON memories BEGIN
              INSERT INTO memories_fts(rowid, content, category)
              VALUES (new.rowid, new.content, new.category);
            END
          ''');
          await db.execute('''
            CREATE TRIGGER memories_ad AFTER DELETE ON memories BEGIN
              INSERT INTO memories_fts(memories_fts, rowid, content, category)
              VALUES('delete', old.rowid, old.content, old.category);
            END
          ''');
          await db.execute('''
            CREATE TRIGGER memories_au AFTER UPDATE ON memories BEGIN
              INSERT INTO memories_fts(memories_fts, rowid, content, category)
              VALUES('delete', old.rowid, old.content, old.category);
              INSERT INTO memories_fts(rowid, content, category)
              VALUES (new.rowid, new.content, new.category);
            END
          ''');
        },
      );
    }
  }

  Future<void> addMemory(MemoryEntry memory) async {
    try {
      final db = await database;
      await db.insert('memories', memory.toMap());
      _memoryController.add(memory);
    } catch (_) {
      _database = null;
      try {
        final db = await database;
        await db.insert('memories', memory.toMap());
        _memoryController.add(memory);
      } catch (_) {}
    }
  }

  Future<List<MemoryEntry>> searchMemory(String query) async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT m.* FROM memories m
        JOIN memories_fts fts ON m.rowid = fts.rowid
        WHERE memories_fts MATCH ?
        ORDER BY rank
        LIMIT 10
      ''', [query]);
      return results.map((map) => MemoryEntry.fromMap(map)).toList();
    } catch (_) {
      _database = null;
      return [];
    }
  }

  Future<List<MemoryEntry>> getMemoriesByCategory(String category) async {
    try {
      final db = await database;
      final results = await db.query(
        'memories',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'updated_at DESC',
      );
      return results.map((map) => MemoryEntry.fromMap(map)).toList();
    } catch (_) {
      _database = null;
      return [];
    }
  }

  Future<List<MemoryEntry>> getAllMemories() async {
    try {
      final db = await database;
      final results = await db.query(
        'memories',
        orderBy: 'updated_at DESC',
      );
      return results.map((map) => MemoryEntry.fromMap(map)).toList();
    } catch (_) {
      _database = null;
      return [];
    }
  }

  Future<void> updateMemory(MemoryEntry memory) async {
    try {
      final db = await database;
      await db.update(
        'memories',
        {
          ...memory.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [memory.id],
      );
    } catch (_) {}
  }

  Future<void> deleteMemory(String id) async {
    try {
      final db = await database;
      await db.delete(
        'memories',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  Future<void> clearAllMemories() async {
    try {
      final db = await database;
      await db.delete('memories');
    } catch (_) {}
  }

  void dispose() {
    _memoryController.close();
  }
}
