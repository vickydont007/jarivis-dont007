import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../email_message.dart';

class EmailService {
  static Database? _database;
  static const _dbName = 'nextron_emails.db';
  final _uuid = const Uuid();

  // IMAP config
  String? _imapHost;
  int _imapPort = 993;

  // SMTP config
  String? _smtpHost;
  int _smtpPort = 587;

  // Auth
  String? _username;
  String? _password;
  String? _displayName;

  bool _isConfigured = false;
  bool _isConnected = false;

  final StreamController<List<EmailMessage>> _inboxController =
      StreamController<List<EmailMessage>>.broadcast();
  Stream<List<EmailMessage>> get inboxStream => _inboxController.stream;

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
          CREATE TABLE emails(
            id TEXT PRIMARY KEY,
            `from` TEXT NOT NULL,
            subject TEXT NOT NULL,
            body TEXT NOT NULL,
            date TEXT NOT NULL,
            is_unread INTEGER DEFAULT 1,
            is_meeting INTEGER DEFAULT 0,
            has_deadline INTEGER DEFAULT 0,
            is_important INTEGER DEFAULT 0,
            `to` TEXT DEFAULT '',
            cc TEXT DEFAULT '',
            bcc TEXT DEFAULT '',
            folder TEXT DEFAULT 'inbox',
            priority TEXT DEFAULT 'normal',
            labels TEXT DEFAULT '',
            in_reply_to TEXT,
            thread_id TEXT,
            has_attachments INTEGER DEFAULT 0,
            size INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_emails_folder ON emails(folder)');
        await db.execute('CREATE INDEX idx_emails_date ON emails(date DESC)');
        await db.execute('CREATE INDEX idx_emails_unread ON emails(is_unread)');
        await db.execute('CREATE INDEX idx_emails_from ON emails(`from`)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try { await db.execute('ALTER TABLE emails ADD COLUMN `to` TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN cc TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN bcc TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN folder TEXT DEFAULT "inbox"'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN priority TEXT DEFAULT "normal"'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN labels TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN in_reply_to TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN thread_id TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN has_attachments INTEGER DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN size INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE emails ADD COLUMN created_at TEXT NOT NULL DEFAULT ""'); } catch (_) {}
        }
      },
    );
  }

  // ─── Configuration ────────────────────────────────────────────

  Future<void> configure({
    required String imapHost,
    int imapPort = 993,
    required String smtpHost,
    int smtpPort = 587,
    required String username,
    required String password,
    String? displayName,
  }) async {
    _imapHost = imapHost;
    _imapPort = imapPort;
    _smtpHost = smtpHost;
    _smtpPort = smtpPort;
    _username = username;
    _password = password;
    _displayName = displayName ?? username;
    _isConfigured = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_imap_host', imapHost);
    await prefs.setInt('email_imap_port', imapPort);
    await prefs.setString('email_smtp_host', smtpHost);
    await prefs.setInt('email_smtp_port', smtpPort);
    await prefs.setString('email_username', username);
    await prefs.setString('email_password', password);
    await prefs.setString('email_display_name', _displayName!);

    await database;
  }

  Future<bool> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _imapHost = prefs.getString('email_imap_host');
    _imapPort = prefs.getInt('email_imap_port') ?? 993;
    _smtpHost = prefs.getString('email_smtp_host');
    _smtpPort = prefs.getInt('email_smtp_port') ?? 587;
    _username = prefs.getString('email_username');
    _password = prefs.getString('email_password');
    _displayName = prefs.getString('email_display_name') ?? _username;
    _isConfigured = _imapHost != null && _username != null && _password != null;
    return _isConfigured;
  }

  bool get isConfigured => _isConfigured;
  bool get isConnected => _isConnected;
  String? get username => _username;
  String? get displayName => _displayName;

  // ─── IMAP Operations ─────────────────────────────────────────

  Future<List<EmailMessage>> fetchEmails({
    EmailFolder folder = EmailFolder.inbox,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    if (!_isConfigured) return getStoredEmails(folder: folder, limit: limit);

    final messages = <EmailMessage>[];
    Socket? socket;

    try {
      socket = await SecureSocket.connect(
        _imapHost!,
        _imapPort,
        timeout: const Duration(seconds: 15),
      );
      _isConnected = true;

      await _imapReadLine(socket);
      await _imapSend(socket, 'A1 LOGIN $_username $_password');
      await _imapReadLine(socket);

      final folderName = _imapFolderName(folder);
      await _imapSend(socket, 'A2 SELECT "$folderName"');
      await _imapReadUntilTag(socket);

      final searchCmd = unreadOnly ? 'SEARCH UNSEEN' : 'SEARCH ALL';
      await _imapSend(socket, 'A3 $searchCmd');
      final searchResponse = await _imapReadUntilTag(socket);

      final ids = searchResponse
          .split(' ')
          .where((s) => int.tryParse(s) != null)
          .take(limit)
          .toList();

      for (final id in ids) {
        try {
          await _imapSend(socket, 'A4 FETCH $id (BODY.PEEK[HEADER.FIELDS (FROM TO CC SUBJECT DATE)])');
          final header = await _imapReadUntilTag(socket);

          await _imapSend(socket, 'A5 FETCH $id (BODY[TEXT])');
          final body = await _imapReadUntilTag(socket);

          final email = _parseImapEmail(id, header, body, folder);
          if (email != null) {
            messages.add(email);
            await _storeEmail(email);
          }
        } catch (_) {}
      }

      await _imapSend(socket, 'A6 LOGOUT');
    } catch (_) {} finally {
      socket?.destroy();
      _isConnected = false;
    }

    if (messages.isNotEmpty) _inboxController.add(messages);
    return messages;
  }

  Future<bool> markAsRead(String emailId) async {
    final db = await database;
    await db.update('emails', {'is_unread': 0}, where: 'id = ?', whereArgs: [emailId]);
    return true;
  }

  Future<bool> markAsUnread(String emailId) async {
    final db = await database;
    await db.update('emails', {'is_unread': 1}, where: 'id = ?', whereArgs: [emailId]);
    return true;
  }

  Future<bool> archiveEmail(String emailId) async {
    final db = await database;
    await db.update('emails', {'folder': 'archive'}, where: 'id = ?', whereArgs: [emailId]);
    return true;
  }

  Future<bool> moveToTrash(String emailId) async {
    final db = await database;
    await db.update('emails', {'folder': 'trash'}, where: 'id = ?', whereArgs: [emailId]);
    return true;
  }

  Future<bool> addLabel(String emailId, String label) async {
    final db = await database;
    final result = await db.query('emails', where: 'id = ?', whereArgs: [emailId], limit: 1);
    if (result.isEmpty) return false;
    final existing = (result.first['labels'] as String?) ?? '';
    final labels = existing.split(',').where((s) => s.isNotEmpty).toList();
    if (!labels.contains(label)) {
      labels.add(label);
      await db.update('emails', {'labels': labels.join(',')}, where: 'id = ?', whereArgs: [emailId]);
    }
    return true;
  }

  Future<bool> removeLabel(String emailId, String label) async {
    final db = await database;
    final result = await db.query('emails', where: 'id = ?', whereArgs: [emailId], limit: 1);
    if (result.isEmpty) return false;
    final existing = (result.first['labels'] as String?) ?? '';
    final labels = existing.split(',').where((s) => s.isNotEmpty && s != label).toList();
    await db.update('emails', {'labels': labels.join(',')}, where: 'id = ?', whereArgs: [emailId]);
    return true;
  }

  // ─── SMTP Send ────────────────────────────────────────────────

  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
    List<String> bcc = const [],
    String? inReplyTo,
  }) async {
    // Store locally first
    final email = EmailMessage(
      id: _uuid.v4(),
      from: _username ?? '',
      subject: subject,
      body: body,
      date: DateTime.now(),
      isUnread: false,
      to: [to],
      cc: cc,
      bcc: bcc,
      folder: EmailFolder.sent,
      inReplyTo: inReplyTo,
    );
    await _storeEmail(email);

    if (!_isConfigured || _smtpHost == null) return true; // saved locally

    Socket? socket;
    try {
      socket = await SecureSocket.connect(
        _smtpHost!,
        _smtpPort,
        timeout: const Duration(seconds: 15),
      );

      final response = await _smtpRead(socket);
      if (!response.startsWith('220')) {
        socket.destroy();
        return true; // saved locally even if SMTP fails
      }

      await _smtpSend(socket, 'EHLO localhost');
      await _smtpRead(socket);

      await _smtpSend(socket, 'STARTTLS');
      final starttlsResp = await _smtpRead(socket);
      if (!starttlsResp.startsWith('220')) {
        socket.destroy();
        return true;
      }

      // Upgrade to TLS
      final secureSocket = await SecureSocket.connect(
        _smtpHost!,
        _smtpPort,
        timeout: const Duration(seconds: 15),
      );

      await _smtpSend(secureSocket, 'EHLO localhost');
      await _smtpRead(secureSocket);

      await _smtpSend(secureSocket, 'AUTH LOGIN');
      await _smtpRead(secureSocket);

      await _smtpSend(secureSocket, base64.encode(utf8.encode(_username!)));
      await _smtpRead(secureSocket);

      await _smtpSend(secureSocket, base64.encode(utf8.encode(_password!)));
      await _smtpRead(secureSocket);

      await _smtpSend(secureSocket, 'MAIL FROM:<$_username>');
      await _smtpRead(secureSocket);

      await _smtpSend(secureSocket, 'RCPT TO:<$to>');
      await _smtpRead(secureSocket);

      for (final ccAddr in cc) {
        await _smtpSend(secureSocket, 'RCPT TO:<$ccAddr>');
        await _smtpRead(secureSocket);
      }

      await _smtpSend(secureSocket, 'DATA');
      await _smtpRead(secureSocket);

      final mimeMessage = _buildMimeMessage(
        from: _displayName != null ? '$_displayName <$_username>' : _username!,
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        inReplyTo: inReplyTo,
      );
      await _smtpSend(secureSocket, '$mimeMessage\r\n.');
      await _smtpRead(secureSocket);

      await _smtpSend(secureSocket, 'QUIT');
      secureSocket.destroy();
      return true;
    } catch (_) {
      socket?.destroy();
      return true; // saved locally even if send fails
    }
  }

  String _buildMimeMessage({
    required String from,
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
    String? inReplyTo,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('From: $from');
    buffer.writeln('To: $to');
    if (cc.isNotEmpty) buffer.writeln('Cc: ${cc.join(", ")}');
    buffer.writeln('Subject: $subject');
    buffer.writeln('MIME-Version: 1.0');
    buffer.writeln('Content-Type: text/plain; charset=utf-8');
    if (inReplyTo != null) {
      buffer.writeln('In-Reply-To: $inReplyTo');
      buffer.writeln('References: $inReplyTo');
    }
    buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Message-ID: <${_uuid.v4()}@nextron.ai>');
    buffer.writeln();
    buffer.write(body);
    return buffer.toString();
  }

  Future<void> _smtpSend(Socket socket, String data) async {
    socket.write('$data\r\n');
    await socket.flush();
  }

  Future<String> _smtpRead(Socket socket) async {
    final completer = Completer<String>();
    var buffer = '';
    final sub = socket.listen(
      (data) {
        buffer += utf8.decode(data);
        if (buffer.contains('\r\n')) {
          if (!completer.isCompleted) completer.complete(buffer.trim());
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.complete(buffer.trim());
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(buffer.trim());
      },
    );
    final result = await completer.future.timeout(const Duration(seconds: 15));
    await sub.cancel();
    return result;
  }

  // ─── Local CRUD ──────────────────────────────────────────────

  Future<List<EmailMessage>> getStoredEmails({
    EmailFolder folder = EmailFolder.inbox,
    int limit = 50,
    String? searchQuery,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where = 'folder = ? AND (subject LIKE ? OR `from` LIKE ? OR body LIKE ?)';
      whereArgs = [folder.name, '%$searchQuery%', '%$searchQuery%', '%$searchQuery%'];
    } else {
      where = 'folder = ?';
      whereArgs = [folder.name];
    }

    final results = await db.query(
      'emails',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<List<EmailMessage>> getUnreadEmails({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'is_unread = 1 AND folder = ?',
      whereArgs: [EmailFolder.inbox.name],
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<List<EmailMessage>> searchEmails(String query, {int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'subject LIKE ? OR `from` LIKE ? OR body LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<int> getUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE is_unread = 1 AND folder = ?',
      [EmailFolder.inbox.name],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTotalCount({EmailFolder folder = EmailFolder.inbox}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE folder = ?',
      [folder.name],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<EmailMessage>> getImportantEmails({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'is_important = 1',
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<List<EmailMessage>> getMeetingEmails({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'is_meeting = 1',
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<List<EmailMessage>> getActionRequiredEmails({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'emails',
      where: 'has_deadline = 1 OR is_important = 1',
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map(_emailFromRow).toList();
  }

  Future<EmailMessage?> getEmail(String emailId) async {
    final db = await database;
    final results = await db.query('emails', where: 'id = ?', whereArgs: [emailId], limit: 1);
    if (results.isEmpty) return null;
    return _emailFromRow(results.first);
  }

  Future<bool> deleteEmail(String emailId) async {
    final db = await database;
    await db.delete('emails', where: 'id = ?', whereArgs: [emailId]);
    return true;
  }

  Future<Map<String, dynamic>> getEmailStats() async {
    final db = await database;
    final unread = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE is_unread = 1 AND folder = ?',
      [EmailFolder.inbox.name],
    );
    final total = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE folder = ?',
      [EmailFolder.inbox.name],
    );
    final meetings = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE is_meeting = 1 AND folder = ?',
      [EmailFolder.inbox.name],
    );
    final deadlines = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE has_deadline = 1 AND folder = ?',
      [EmailFolder.inbox.name],
    );
    final important = await db.rawQuery(
      'SELECT COUNT(*) as count FROM emails WHERE is_important = 1 AND folder = ?',
      [EmailFolder.inbox.name],
    );

    return {
      'unread': (unread.first['count'] as int?) ?? 0,
      'total': (total.first['count'] as int?) ?? 0,
      'meetings': (meetings.first['count'] as int?) ?? 0,
      'deadlines': (deadlines.first['count'] as int?) ?? 0,
      'important': (important.first['count'] as int?) ?? 0,
    };
  }

  // ─── Draft System ─────────────────────────────────────────────

  Future<EmailMessage> saveDraft({
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
  }) async {
    final draft = EmailMessage(
      id: _uuid.v4(),
      from: _username ?? '',
      subject: subject,
      body: body,
      date: DateTime.now(),
      to: [to],
      cc: cc,
      folder: EmailFolder.drafts,
    );
    await _storeEmail(draft);
    return draft;
  }

  Future<List<EmailMessage>> getDrafts() async {
    return getStoredEmails(folder: EmailFolder.drafts);
  }

  Future<bool> updateDraft(String draftId, {
    String? to,
    String? subject,
    String? body,
    List<String>? cc,
  }) async {
    final db = await database;
    final existing = await db.query('emails', where: 'id = ?', whereArgs: [draftId], limit: 1);
    if (existing.isEmpty) return false;

    final updates = <String, dynamic>{};
    if (to != null) updates['`to`'] = to;
    if (subject != null) updates['subject'] = subject;
    if (body != null) updates['body'] = body;
    if (cc != null) updates['cc'] = cc.join(',');
    if (updates.isEmpty) return false;

    await db.update('emails', updates, where: 'id = ?', whereArgs: [draftId]);
    return true;
  }

  Future<bool> deleteDraft(String draftId) async {
    return deleteEmail(draftId);
  }

  // ─── Helpers ──────────────────────────────────────────────────

  String _imapFolderName(EmailFolder folder) {
    switch (folder) {
      case EmailFolder.inbox: return 'INBOX';
      case EmailFolder.sent: return 'Sent Messages';
      case EmailFolder.drafts: return 'Drafts';
      case EmailFolder.trash: return 'Trash';
      case EmailFolder.archive: return 'Archive';
      case EmailFolder.spam: return 'Junk';
    }
  }

  Future<void> _storeEmail(EmailMessage email) async {
    final db = await database;
    final map = email.toMap();
    map['created_at'] = DateTime.now().toIso8601String();
    map['body'] = email.body.length > 5000 ? email.body.substring(0, 5000) : email.body;
    await db.insert('emails', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  EmailMessage _emailFromRow(Map<String, dynamic> row) {
    return EmailMessage.fromMap(row);
  }

  EmailMessage? _parseImapEmail(String id, String header, String body, EmailFolder folder) {
    final from = _extractHeader(header, 'FROM:');
    final subject = _extractHeader(header, 'SUBJECT:');
    final dateStr = _extractHeader(header, 'DATE:');
    final toRaw = _extractHeader(header, 'TO:');
    final ccRaw = _extractHeader(header, 'CC:');

    if (subject == null && from == null) return null;

    final bodyClean = _decodeMime(body);
    final subjectDecoded = subject != null ? _decodeMime(subject.trim()) : '(No subject)';

    DateTime date;
    try {
      date = DateTime.parse(dateStr ?? '');
    } catch (_) {
      date = DateTime.now();
    }

    final hasMeeting = bodyClean.contains(RegExp(r'meeting|agenda|calendar|invite|schedule|rsvp|zoom|teams', caseSensitive: false));
    final hasDeadline = bodyClean.contains(RegExp(r'deadline|due date|due by|asap|urgent|eod|end of day', caseSensitive: false));
    final isImportant = _isImportantSender(from ?? '');

    return EmailMessage(
      id: id,
      from: _decodeMime(from ?? 'Unknown'),
      subject: subjectDecoded,
      body: bodyClean,
      date: date,
      isUnread: true,
      isMeeting: hasMeeting,
      hasDeadline: hasDeadline,
      isImportant: isImportant,
      to: toRaw != null ? [_decodeMime(toRaw)] : [],
      cc: ccRaw != null ? [_decodeMime(ccRaw)] : [],
      folder: folder,
    );
  }

  String? _extractHeader(String header, String field) {
    for (final line in header.split('\n')) {
      if (line.toUpperCase().trim().startsWith(field)) {
        return line.substring(field.length).trim();
      }
    }
    return null;
  }

  String _decodeMime(String text) {
    return text
        .replaceAllMapped(RegExp(r'=\?[^?]+\?[Bb]\?([^?]+)\?='), (m) {
          try { return utf8.decode(base64.decode(m.group(1)!)); }
          catch (_) { return m.group(0)!; }
        })
        .replaceAllMapped(RegExp(r'=\?[^?]+\?[Qq]\?([^?]+)\?='), (m) {
          try { return m.group(1)!.replaceAll('_', ' '); }
          catch (_) { return m.group(0)!; }
        })
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\r?\n'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isImportantSender(String sender) {
    final patterns = ['manager', 'boss', 'ceo', 'cto', 'lead', 'director', 'hr', 'recruiter', 'client', 'customer', 'investor', 'partner'];
    final lower = sender.toLowerCase();
    return patterns.any((p) => lower.contains(p));
  }

  // ─── IMAP Helpers ─────────────────────────────────────────────

  Future<void> _imapSend(Socket socket, String command) async {
    socket.write('$command\r\n');
    await socket.flush();
  }

  Future<String> _imapReadLine(Socket socket) async {
    final completer = Completer<String>();
    var buffer = '';
    final sub = socket.listen(
      (data) {
        buffer += utf8.decode(data);
        if (buffer.contains('\r\n') && !completer.isCompleted) {
          completer.complete(buffer.split('\r\n').first);
        }
      },
      onError: (e) { if (!completer.isCompleted) completer.complete(buffer); },
      onDone: () { if (!completer.isCompleted) completer.complete(buffer); },
    );
    final result = await completer.future.timeout(const Duration(seconds: 10));
    await sub.cancel();
    return result;
  }

  Future<String> _imapReadUntilTag(Socket socket) async {
    final completer = Completer<String>();
    var buffer = '';
    final sub = socket.listen(
      (data) {
        buffer += utf8.decode(data);
        if ((buffer.contains('OK') || buffer.contains('NO') || buffer.contains('BAD')) && !completer.isCompleted) {
          completer.complete(buffer);
        }
      },
      onError: (e) { if (!completer.isCompleted) completer.complete(buffer); },
      onDone: () { if (!completer.isCompleted) completer.complete(buffer); },
    );
    final result = await completer.future.timeout(const Duration(seconds: 15));
    await sub.cancel();
    return result;
  }

  void dispose() {
    _inboxController.close();
  }
}
