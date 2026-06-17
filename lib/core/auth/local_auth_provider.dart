import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'auth_user.dart';
import 'auth_session.dart';

class LocalAuthProvider {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'nextron_users.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            display_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_login TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions(
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            login_time TEXT NOT NULL,
            last_active TEXT NOT NULL,
            remember_me TEXT NOT NULL DEFAULT '1',
            FOREIGN KEY (user_id) REFERENCES users(id)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_sessions_user ON sessions(user_id)
        ''');
      },
    );
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(salt + password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<AuthUser> createUser(
      String email, String password, String displayName) async {
    final db = await database;
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    final storedHash = '$salt:$hash';
    final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id': id,
      'email': email.toLowerCase().trim(),
      'password_hash': storedHash,
      'display_name': displayName.trim(),
      'created_at': now,
    });

    return AuthUser(
      id: id,
      email: email.toLowerCase().trim(),
      displayName: displayName.trim(),
      createdAt: DateTime.parse(now),
    );
  }

  Future<AuthUser?> verifyPassword(String email, String password) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final storedHash = row['password_hash'] as String;
    final parts = storedHash.split(':');
    if (parts.length != 2) return null;

    final salt = parts[0];
    final expectedHash = parts[1];
    final computedHash = _hashPassword(password, salt);

    if (computedHash != expectedHash) return null;

    final now = DateTime.now().toIso8601String();
    await db.update(
      'users',
      {'last_login': now},
      where: 'id = ?',
      whereArgs: [row['id']],
    );

    return AuthUser.fromMap({...row, 'last_login': now});
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM users WHERE email = ?',
      [email.toLowerCase().trim()],
    ));
    return (count ?? 0) > 0;
  }

  Future<AuthSession> createSession(
      String userId, {bool rememberMe = true}) async {
    final db = await database;
    final id = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.insert('sessions', {
      'id': id,
      'user_id': userId,
      'login_time': now,
      'last_active': now,
      'remember_me': rememberMe ? '1' : '0',
    });

    return AuthSession(
      id: id,
      userId: userId,
      loginTime: DateTime.parse(now),
      lastActive: DateTime.parse(now),
      rememberMe: rememberMe,
    );
  }

  Future<AuthSession?> getActiveSession() async {
    final db = await database;
    final results = await db.query(
      'sessions',
      where: 'remember_me = ?',
      whereArgs: ['1'],
      orderBy: 'last_active DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AuthSession.fromMap(results.first);
  }

  Future<AuthUser?> getUserById(String id) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AuthUser.fromMap(results.first);
  }

  Future<void> updateSessionActivity(String sessionId) async {
    final db = await database;
    await db.update(
      'sessions',
      {'last_active': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> deleteAllSessions(String userId) async {
    final db = await database;
    await db.delete('sessions', where: 'user_id = ?', whereArgs: [userId]);
  }

  void dispose() {
    _database?.close();
    _database = null;
  }
}
