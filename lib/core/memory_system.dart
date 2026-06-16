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
        version: 3,
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

          // Create conversation_sessions table
          await db.execute('''
            CREATE TABLE conversation_sessions(
              session_id TEXT PRIMARY KEY,
              messages_json TEXT NOT NULL,
              summaries_json TEXT NOT NULL,
              current_summary TEXT,
              message_count INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // Memory Consolidation tables
          await _createConsolidationTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE conversation_sessions(
                session_id TEXT PRIMARY KEY,
                messages_json TEXT NOT NULL,
                summaries_json TEXT NOT NULL,
                current_summary TEXT,
                message_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 3) {
            await _createConsolidationTables(db);
          }
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
        version: 3,
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

          await db.execute('''
            CREATE TABLE conversation_sessions(
              session_id TEXT PRIMARY KEY,
              messages_json TEXT NOT NULL,
              summaries_json TEXT NOT NULL,
              current_summary TEXT,
              message_count INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await _createConsolidationTables(db);
        },
      );
    }
  }

  static Future<void> _createConsolidationTables(Database db) async {
    // Consolidated memories - long-term knowledge extracted from conversations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS consolidated_memories(
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        importance_score INTEGER DEFAULT 50,
        confidence_score REAL DEFAULT 0.5,
        reinforcement_count INTEGER DEFAULT 1,
        last_reinforced_at TEXT,
        source TEXT DEFAULT 'conversation',
        canonical_id TEXT,
        metadata TEXT DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS consolidated_memories_fts USING fts5(
        content,
        category,
        source,
        content='consolidated_memories',
        content_rowid='rowid'
      )
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS consolidated_memories_ai AFTER INSERT ON consolidated_memories BEGIN
        INSERT INTO consolidated_memories_fts(rowid, content, category, source)
        VALUES (new.rowid, new.content, new.category, new.source);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS consolidated_memories_ad AFTER DELETE ON consolidated_memories BEGIN
        INSERT INTO consolidated_memories_fts(consolidated_memories_fts, rowid, content, category, source)
        VALUES('delete', old.rowid, old.content, old.category, old.source);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS consolidated_memories_au AFTER UPDATE ON consolidated_memories BEGIN
        INSERT INTO consolidated_memories_fts(consolidated_memories_fts, rowid, content, category, source)
        VALUES('delete', old.rowid, old.content, old.category, old.source);
        INSERT INTO consolidated_memories_fts(rowid, content, category, source)
        VALUES (new.rowid, new.content, new.category, new.source);
      END
    ''');

    // User profile - auto-maintained structured profile
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile(
        id TEXT PRIMARY KEY,
        field_name TEXT NOT NULL,
        field_value TEXT NOT NULL,
        confidence REAL DEFAULT 0.5,
        source TEXT DEFAULT 'conversation',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(field_name, field_value)
      )
    ''');

    // Memory links - connections between related memories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_links(
        id TEXT PRIMARY KEY,
        from_memory_id TEXT NOT NULL,
        to_memory_id TEXT NOT NULL,
        relationship TEXT NOT NULL,
        strength REAL DEFAULT 0.5,
        created_at TEXT NOT NULL,
        UNIQUE(from_memory_id, to_memory_id, relationship)
      )
    ''');
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

  // ─── Conversation Session Persistence ──────────────────────────

  /// Save the current conversation state to a session
  Future<void> saveConversationSession({
    required String sessionId,
    required List<Map<String, String>> messages,
    required List<Map<String, String>> summaries,
    String? currentSummary,
    required int messageCount,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      
      await db.insert(
        'conversation_sessions',
        {
          'session_id': sessionId,
          'messages_json': jsonEncode(messages),
          'summaries_json': jsonEncode(summaries),
          'current_summary': currentSummary,
          'message_count': messageCount,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Silently fail - don't crash on persistence issues
    }
  }

  /// Load the most recent conversation session
  Future<Map<String, dynamic>?> loadLatestConversationSession() async {
    try {
      final db = await database;
      final results = await db.query(
        'conversation_sessions',
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      
      if (results.isEmpty) return null;
      
      final row = results.first;
      return {
        'session_id': row['session_id'],
        'messages': jsonDecode(row['messages_json'] as String) as List<dynamic>,
        'summaries': jsonDecode(row['summaries_json'] as String) as List<dynamic>,
        'current_summary': row['current_summary'],
        'message_count': row['message_count'] as int,
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      };
    } catch (e) {
      return null;
    }
  }

  /// Get all conversation sessions (for UI)
  Future<List<Map<String, dynamic>>> getAllConversationSessions({int limit = 20}) async {
    try {
      final db = await database;
      final results = await db.query(
        'conversation_sessions',
        orderBy: 'updated_at DESC',
        limit: limit,
      );
      
      return results.map((row) => {
        'session_id': row['session_id'],
        'message_count': row['message_count'] as int,
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete a conversation session
  Future<void> deleteConversationSession(String sessionId) async {
    try {
      final db = await database;
      await db.delete(
        'conversation_sessions',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear all conversation sessions
  Future<void> clearAllConversationSessions() async {
    try {
      final db = await database;
      await db.delete('conversation_sessions');
    } catch (e) {
      // Silently fail
    }
  }
}
