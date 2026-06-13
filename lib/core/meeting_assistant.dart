import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class MeetingNote {
  final String id;
  final String meetingId;
  final String content;
  final String? speaker;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  MeetingNote({
    required this.id,
    required this.meetingId,
    required this.content,
    this.speaker,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'content': content,
      'speaker': speaker,
      'timestamp': timestamp.toIso8601String(),
      'metadata': jsonEncode(metadata),
    };
  }

  factory MeetingNote.fromMap(Map<String, dynamic> map) {
    return MeetingNote(
      id: map['id'],
      meetingId: map['meeting_id'],
      content: map['content'],
      speaker: map['speaker'],
      timestamp: DateTime.parse(map['timestamp']),
      metadata: jsonDecode(map['metadata'] ?? '{}'),
    );
  }
}

class Meeting {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> participants;
  final String? recordingPath;
  final String? summary;
  final Map<String, dynamic> metadata;

  Meeting({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.participants = const [],
    this.recordingPath,
    this.summary,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'participants': jsonEncode(participants),
      'recording_path': recordingPath,
      'summary': summary,
      'metadata': jsonEncode(metadata),
    };
  }

  factory Meeting.fromMap(Map<String, dynamic> map) {
    return Meeting(
      id: map['id'],
      title: map['title'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      participants: List<String>.from(jsonDecode(map['participants'] ?? '[]')),
      recordingPath: map['recording_path'],
      summary: map['summary'],
      metadata: jsonDecode(map['metadata'] ?? '{}'),
    );
  }
}

class MeetingAssistant {
  static Database? _database;
  final StreamController<MeetingNote> _noteController =
      StreamController<MeetingNote>.broadcast();

  Stream<MeetingNote> get noteStream => _noteController.stream;

  MeetingAssistant();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_meetings.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE meetings(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            participants TEXT DEFAULT '[]',
            recording_path TEXT,
            summary TEXT,
            metadata TEXT DEFAULT '{}'
          )
        ''');

        await db.execute('''
          CREATE TABLE meeting_notes(
            id TEXT PRIMARY KEY,
            meeting_id TEXT NOT NULL,
            content TEXT NOT NULL,
            speaker TEXT,
            timestamp TEXT NOT NULL,
            metadata TEXT DEFAULT '{}',
            FOREIGN KEY (meeting_id) REFERENCES meetings(id)
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_notes_meeting ON meeting_notes(meeting_id)
        ''');
      },
    );
  }

  Future<String> startMeeting({
    required String title,
    List<String> participants = const [],
  }) async {
    final meeting = Meeting(
      id: const Uuid().v4(),
      title: title,
      startTime: DateTime.now(),
      participants: participants,
    );

    final db = await database;
    await db.insert('meetings', meeting.toMap());
    return meeting.id;
  }

  Future<void> endMeeting(String meetingId) async {
    final db = await database;
    await db.update(
      'meetings',
      {'end_time': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [meetingId],
    );
  }

  Future<void> addNote({
    required String meetingId,
    required String content,
    String? speaker,
    Map<String, dynamic> metadata = const {},
  }) async {
    final note = MeetingNote(
      id: const Uuid().v4(),
      meetingId: meetingId,
      content: content,
      speaker: speaker,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    final db = await database;
    await db.insert('meeting_notes', note.toMap());
    _noteController.add(note);
  }

  Future<List<MeetingNote>> getNotes(String meetingId) async {
    final db = await database;
    final results = await db.query(
      'meeting_notes',
      where: 'meeting_id = ?',
      whereArgs: [meetingId],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => MeetingNote.fromMap(map)).toList();
  }

  Future<List<Meeting>> getMeetings({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'meetings',
      orderBy: 'start_time DESC',
      limit: limit,
    );

    return results.map((map) => Meeting.fromMap(map)).toList();
  }

  Future<void> updateSummary(String meetingId, String summary) async {
    final db = await database;
    await db.update(
      'meetings',
      {'summary': summary},
      where: 'id = ?',
      whereArgs: [meetingId],
    );
  }

  Future<void> deleteMeeting(String meetingId) async {
    final db = await database;
    await db.delete(
      'meeting_notes',
      where: 'meeting_id = ?',
      whereArgs: [meetingId],
    );
    await db.delete(
      'meetings',
      where: 'id = ?',
      whereArgs: [meetingId],
    );
  }

  void dispose() {
    _noteController.close();
  }
}
