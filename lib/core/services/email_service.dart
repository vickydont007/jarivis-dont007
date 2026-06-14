import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailMessage {
  final String id;
  final String sender;
  final String subject;
  final String preview;
  final DateTime date;
  final bool isUnread;
  final bool isMeeting;
  final bool hasDeadline;
  final bool isImportant;

  EmailMessage({
    required this.id,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.date,
    this.isUnread = true,
    this.isMeeting = false,
    this.hasDeadline = false,
    this.isImportant = false,
  });
}

class EmailService {
  static Database? _database;
  static const _dbName = 'nextron_emails.db';

  String? _imapHost;
  int _imapPort = 993;
  String? _username;
  String? _password;
  bool _isConfigured = false;
  bool _isConnected = false;

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
          CREATE TABLE emails(
            id TEXT PRIMARY KEY,
            sender TEXT NOT NULL,
            subject TEXT NOT NULL,
            body TEXT NOT NULL,
            date TEXT NOT NULL,
            is_unread INTEGER DEFAULT 1,
            is_meeting INTEGER DEFAULT 0,
            has_deadline INTEGER DEFAULT 0,
            is_important INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> configure(String host, int port, String username, String password) async {
    _imapHost = host;
    _imapPort = port;
    _username = username;
    _password = password;
    _isConfigured = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_host', host);
    await prefs.setString('email_port', port.toString());
    await prefs.setString('email_username', username);
    await prefs.setString('email_password', password);

    await database;
  }

  Future<bool> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _imapHost = prefs.getString('email_host');
    _imapPort = int.tryParse(prefs.getString('email_port') ?? '993') ?? 993;
    _username = prefs.getString('email_username');
    _password = prefs.getString('email_password');
    _isConfigured = _imapHost != null && _username != null && _password != null;
    return _isConfigured;
  }

  bool get isConfigured => _isConfigured;

  Future<List<EmailMessage>> fetchUnread() async {
    if (!_isConfigured) return [];

    final messages = <EmailMessage>[];
    Socket? socket;

    try {
      socket = await SecureSocket.connect(
        _imapHost!,
        _imapPort,
        timeout: const Duration(seconds: 10),
      );

      _isConnected = true;

      // Read greeting
      await _readLine(socket);

      // Login
      await _sendCommand(socket, 'LOGIN $_username $_password');
      await _readLine(socket);

      // Select inbox
      await _sendCommand(socket, 'SELECT INBOX');
      await _readUntilTag(socket);

      // Search unread
      await _sendCommand(socket, 'SEARCH UNSEEN');
      final searchResponse = await _readUntilTag(socket);
      final ids = searchResponse
          .split(' ')
          .where((s) => int.tryParse(s) != null)
          .take(10)
          .toList();

      for (final id in ids) {
        try {
          await _sendCommand(socket, 'FETCH $id (BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])');
          final header = await _readUntilTag(socket);

          await _sendCommand(socket, 'FETCH $id (BODY[TEXT])');
          final body = await _readUntilTag(socket);

          final email = _parseEmail(id, header, body);
          if (email != null) {
            messages.add(email);
            await _storeEmail(email);
          }
        } catch (e) {
          // Skip problematic email
        }
      }

      // Logout
      await _sendCommand(socket, 'LOGOUT');
    } catch (e) {
      // Connection failed
    } finally {
      socket?.destroy();
      _isConnected = false;
    }

    return messages;
  }

  Future<List<EmailMessage>> getStoredUnread() async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'is_unread = 1',
      orderBy: 'date DESC',
      limit: 20,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<List<EmailMessage>> getMeetingEmails() async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'is_meeting = 1',
      orderBy: 'date DESC',
      limit: 10,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<List<EmailMessage>> searchEmails(String query) async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'subject LIKE ? OR body LIKE ? OR sender LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return results.map(_emailFromRow).toList();
  }

  EmailMessage? _parseEmail(String id, String header, String body) {
    final sender = _extractHeader(header, 'FROM:');
    final subject = _extractHeader(header, 'SUBJECT:');
    final dateStr = _extractHeader(header, 'DATE:');

    if (subject == null) return null;

    final bodyClean = _decodeMime(body);

    final hasMeeting = bodyClean.contains(RegExp(r'meeting|agenda|calendar|invite|schedule|rsvp', caseSensitive: false));
    final hasDeadline = bodyClean.contains(RegExp(r'deadline|due date|due by|asap|urgent|eod|end of day', caseSensitive: false));
    final isImportant = _isImportantSender(sender ?? '');

    DateTime date;
    try {
      date = DateTime.parse(dateStr ?? '');
    } catch (e) {
      date = DateTime.now();
    }

    preview = bodyClean.length > 150 ? bodyClean.substring(0, 150) : bodyClean;

    return EmailMessage(
      id: id,
      sender: sender ?? 'Unknown',
      subject: _decodeMime(subject.trim()),
      preview: bodyClean.length > 150 ? '${bodyClean.substring(0, 150)}...' : bodyClean,
      date: date,
      isUnread: true,
      isMeeting: hasMeeting,
      hasDeadline: hasDeadline,
      isImportant: isImportant,
    );
  }

  // These are used in _parseEmail but might need to be conditionally assigned
  String preview = '';

  String? _extractHeader(String header, String field) {
    for (final line in header.split('\n')) {
      final upper = line.toUpperCase().trim();
      if (upper.startsWith(field)) {
        return line.substring(field.length).trim();
      }
    }
    return null;
  }

  String _decodeMime(String text) {
    return text
        .replaceAllMapped(RegExp(r'=\?[^?]+\?[Bb]\?([^?]+)\?='), (m) {
          try {
            return utf8.decode(base64.decode(m.group(1)!));
          } catch (e) {
            return m.group(0)!;
          }
        })
        .replaceAllMapped(RegExp(r'=\?[^?]+\?[Qq]\?([^?]+)\?='), (m) {
          try {
            return m.group(1)!.replaceAll('_', ' ');
          } catch (e) {
            return m.group(0)!;
          }
        })
        .replaceAll(RegExp(r'\r?\n'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isImportantSender(String sender) {
    final importantPatterns = [
      'manager', 'boss', 'ceo', 'cto', 'lead', 'director',
      'hr', 'recruiter', 'client', 'customer', 'support',
    ];
    final lower = sender.toLowerCase();
    return importantPatterns.any((p) => lower.contains(p));
  }

  Future<void> _storeEmail(EmailMessage email) async {
    final db = await database;
    await db.insert('emails', {
      'id': email.id,
      'sender': email.sender,
      'subject': email.subject,
      'body': email.preview.length > 2000 ? email.preview.substring(0, 2000) : email.preview,
      'date': email.date.toIso8601String(),
      'is_unread': 1,
      'is_meeting': email.isMeeting ? 1 : 0,
      'has_deadline': email.hasDeadline ? 1 : 0,
      'is_important': email.isImportant ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  EmailMessage _emailFromRow(Map<String, dynamic> row) {
    return EmailMessage(
      id: row['id'] as String,
      sender: row['sender'] as String,
      subject: row['subject'] as String,
      preview: (row['body'] as String?) ?? '',
      date: DateTime.parse(row['date'] as String),
      isUnread: (row['is_unread'] as int) == 1,
      isMeeting: (row['is_meeting'] as int) == 1,
      hasDeadline: (row['has_deadline'] as int) == 1,
      isImportant: (row['is_important'] as int) == 1,
    );
  }

  Future<void> _sendCommand(Socket socket, String command) async {
    socket.write('$command\r\n');
    await socket.flush();
  }

  Future<String> _readLine(Socket socket) async {
    final completer = Completer<String>();
    var buffer = '';
    socket.listen(
      (data) {
        buffer += utf8.decode(data);
        if (buffer.contains('\r\n')) {
          final lines = buffer.split('\r\n');
          completer.complete(lines[0]);
        }
      },
      onError: (e) => completer.completeError(e),
      onDone: () => completer.complete(buffer),
      cancelOnError: true,
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<String> _readUntilTag(Socket socket) async {
    final completer = Completer<String>();
    var buffer = '';
    socket.listen(
      (data) {
        buffer += utf8.decode(data);
        if (buffer.contains('OK') || buffer.contains('NO') || buffer.contains('BAD')) {
          completer.complete(buffer);
        }
      },
      onError: (e) => completer.complete(buffer),
      onDone: () => completer.complete(buffer),
      cancelOnError: true,
    );
    return completer.future.timeout(const Duration(seconds: 15));
  }
}
