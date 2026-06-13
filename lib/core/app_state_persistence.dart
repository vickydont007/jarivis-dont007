import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class AppStatePersistence {
  static Database? _database;
  static const String _settingsTable = 'app_settings';
  static const String _sessionsTable = 'chat_sessions';
  static const String _messagesTable = 'chat_messages';

  AppStatePersistence();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_state.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_settingsTable(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_sessionsTable(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            metadata TEXT DEFAULT '{}'
          )
        ''');

        await db.execute('''
          CREATE TABLE $_messagesTable(
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            metadata TEXT DEFAULT '{}',
            FOREIGN KEY (session_id) REFERENCES $_sessionsTable(id)
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_messages_session ON $_messagesTable(session_id)
        ''');
      },
    );
  }

  Future<void> saveSetting(String key, dynamic value) async {
    final db = await database;
    await db.insert(
      _settingsTable,
      {
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<T?> loadSetting<T>(String key, {T? defaultValue}) async {
    final db = await database;
    final results = await db.query(
      _settingsTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return defaultValue;

    final value = jsonDecode(results.first['value'] as String);
    return value as T;
  }

  Future<Map<String, dynamic>> loadAllSettings() async {
    final db = await database;
    final results = await db.query(_settingsTable);

    final settings = <String, dynamic>{};
    for (final row in results) {
      settings[row['key'] as String] = jsonDecode(row['value'] as String);
    }
    return settings;
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete(
      _settingsTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<String> createSession({String? title, Map<String, dynamic>? metadata}) async {
    final db = await database;
    final id = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.insert(_sessionsTable, {
      'id': id,
      'title': title ?? 'Chat ${DateTime.now().toString().substring(0, 16)}',
      'created_at': now,
      'updated_at': now,
      'metadata': jsonEncode(metadata ?? {}),
    });

    return id;
  }

  Future<void> saveMessage({
    required String sessionId,
    required String role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await database;
    final id = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert(_messagesTable, {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': jsonEncode(metadata ?? {}),
    });

    await db.update(
      _sessionsTable,
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(String sessionId, {int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      _messagesTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return results.map((row) => {
      'id': row['id'],
      'role': row['role'],
      'content': row['content'],
      'timestamp': row['timestamp'],
      'metadata': jsonDecode(row['metadata'] as String? ?? '{}'),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getSessions({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      _sessionsTable,
      orderBy: 'updated_at DESC',
      limit: limit,
    );

    return results.map((row) => {
      'id': row['id'],
      'title': row['title'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'metadata': jsonDecode(row['metadata'] as String? ?? '{}'),
    }).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(
      _messagesTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      _sessionsTable,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_settingsTable);
    await db.delete(_messagesTable);
    await db.delete(_sessionsTable);
  }

  void dispose() {
    _database?.close();
    _database = null;
  }
}
