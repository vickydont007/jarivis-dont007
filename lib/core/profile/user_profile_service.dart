import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'user_profile.dart';

class UserProfileService {
  static Database? _database;
  UserProfile? _cachedProfile;
  String _userId = '';

  void setUserId(String userId) {
    _userId = userId;
    _cachedProfile = null;
  }

  String get userId => _userId;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'nextron_profiles.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_profiles(
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT DEFAULT '',
            nickname TEXT DEFAULT '',
            occupation TEXT DEFAULT '',
            company TEXT DEFAULT '',
            projects TEXT DEFAULT '[]',
            goals TEXT DEFAULT '[]',
            skills TEXT DEFAULT '[]',
            interests TEXT DEFAULT '[]',
            preferences TEXT DEFAULT '{}',
            relationships TEXT DEFAULT '[]',
            important_dates TEXT DEFAULT '[]',
            location TEXT DEFAULT '',
            bio TEXT DEFAULT '',
            confidence_score REAL DEFAULT 0.0,
            completeness_score REAL DEFAULT 0.0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_profiles_user ON user_profiles(user_id)');
      },
    );
  }

  Future<UserProfile> load() async {
    if (_cachedProfile != null && _cachedProfile!.userId == _userId) {
      return _cachedProfile!;
    }
    if (_userId.isEmpty) return _createEmpty();

    final db = await database;
    final results = await db.query(
      'user_profiles',
      where: 'user_id = ?',
      whereArgs: [_userId],
      limit: 1,
    );

    if (results.isEmpty) {
      _cachedProfile = _createEmpty();
      return _cachedProfile!;
    }

    _cachedProfile = UserProfile.fromMap(results.first);
    return _cachedProfile!;
  }

  UserProfile _createEmpty() {
    final now = DateTime.now();
    return UserProfile(
      id: 'prof_${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> save(UserProfile profile) async {
    _cachedProfile = profile;
    if (profile.userId.isEmpty) return;
    final db = await database;
    await db.insert(
      'user_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateField(String field, String value) async {
    final profile = await load();
    final updated = profile.copyWith();
    switch (field) {
      case 'name':
        updated.name = value;
      case 'nickname':
        updated.nickname = value;
      case 'occupation':
        updated.occupation = value;
      case 'company':
        updated.company = value;
      case 'location':
        updated.location = value;
      case 'bio':
        updated.bio = value;
    }
    updated.completenessScore = _calculateCompleteness(updated);
    await save(updated);
  }

  Future<void> addProject(String project) async {
    final profile = await load();
    if (profile.projects.contains(project)) {
      await _boostConfidence();
      return;
    }
    final updated = profile.copyWith(projects: [...profile.projects, project]);
    updated.completenessScore = _calculateCompleteness(updated);
    await save(updated);
  }

  Future<void> addGoal(String goal) async {
    final profile = await load();
    if (profile.goals.contains(goal)) {
      await _boostConfidence();
      return;
    }
    final updated = profile.copyWith(goals: [...profile.goals, goal]);
    updated.completenessScore = _calculateCompleteness(updated);
    await save(updated);
  }

  Future<void> addSkill(String skill) async {
    final profile = await load();
    if (profile.skills.contains(skill)) {
      await _boostConfidence();
      return;
    }
    final updated = profile.copyWith(skills: [...profile.skills, skill]);
    updated.completenessScore = _calculateCompleteness(updated);
    await save(updated);
  }

  Future<void> addInterest(String interest) async {
    final profile = await load();
    if (profile.interests.contains(interest)) {
      await _boostConfidence();
      return;
    }
    final updated = profile.copyWith(interests: [...profile.interests, interest]);
    updated.completenessScore = _calculateCompleteness(updated);
    await save(updated);
  }

  Future<void> addPreference(String key, dynamic value) async {
    final profile = await load();
    final prefs = Map<String, dynamic>.from(profile.preferences);
    if (prefs.containsKey(key)) {
      await _boostConfidence();
      return;
    }
    prefs[key] = value;
    final updated = profile.copyWith(preferences: prefs);
    updated.completenessScore = _calculateCompleteness(updated);
    await save(updated);
  }

  Future<void> addRelationship(Map<String, dynamic> rel) async {
    final profile = await load();
    final updated = profile.copyWith(
      relationships: [...profile.relationships, rel],
    );
    await save(updated);
  }

  Future<void> addImportantDate(Map<String, dynamic> date) async {
    final profile = await load();
    final updated = profile.copyWith(
      importantDates: [...profile.importantDates, date],
    );
    await save(updated);
  }

  Future<void> _boostConfidence() async {
    final profile = await load();
    final newConf = (profile.confidenceScore + 0.05).clamp(0.0, 1.0);
    final updated = profile.copyWith(confidenceScore: newConf);
    await save(updated);
  }

  Future<void> mergeFacts({
    required String content,
    required String category,
    double confidence = 0.5,
  }) async {
    var profile = await load();
    final lower = content.toLowerCase();

    switch (category) {
      case 'name':
        if (profile.name.isEmpty) {
          profile = profile.copyWith(name: content);
        } else {
          profile = profile.copyWith(
            confidenceScore: (profile.confidenceScore + 0.05).clamp(0.0, 1.0),
          );
        }
      case 'project':
        if (!profile.projects.any((p) => p.toLowerCase() == lower)) {
          profile = profile.copyWith(projects: [...profile.projects, content]);
        } else {
          profile = profile.copyWith(
            confidenceScore: (profile.confidenceScore + 0.05).clamp(0.0, 1.0),
          );
        }
      case 'goal':
        if (!profile.goals.any((g) => g.toLowerCase() == lower)) {
          profile = profile.copyWith(goals: [...profile.goals, content]);
        } else {
          profile = profile.copyWith(
            confidenceScore: (profile.confidenceScore + 0.05).clamp(0.0, 1.0),
          );
        }
      case 'skill':
        if (!profile.skills.any((s) => s.toLowerCase() == lower)) {
          profile = profile.copyWith(skills: [...profile.skills, content]);
        } else {
          profile = profile.copyWith(
            confidenceScore: (profile.confidenceScore + 0.05).clamp(0.0, 1.0),
          );
        }
      case 'interest':
        if (!profile.interests.any((i) => i.toLowerCase() == lower)) {
          profile = profile.copyWith(interests: [...profile.interests, content]);
        } else {
          profile = profile.copyWith(
            confidenceScore: (profile.confidenceScore + 0.05).clamp(0.0, 1.0),
          );
        }
      case 'preference':
        final key = 'pref_${content.hashCode}';
        if (!profile.preferences.containsKey(key)) {
          final prefs = Map<String, dynamic>.from(profile.preferences);
          prefs[key] = content;
          profile = profile.copyWith(preferences: prefs);
        } else {
          profile = profile.copyWith(
            confidenceScore: (profile.confidenceScore + 0.05).clamp(0.0, 1.0),
          );
        }
      case 'relationship':
        profile = profile.copyWith(
          relationships: [
            ...profile.relationships,
            {'type': 'relation', 'value': content}
          ],
        );
      case 'date':
        profile = profile.copyWith(
          importantDates: [
            ...profile.importantDates,
            {'type': 'date', 'value': content}
          ],
        );
    }

    profile.completenessScore = _calculateCompleteness(profile);
    profile.updatedAt = DateTime.now();
    await save(profile);
  }

  double _calculateCompleteness(UserProfile profile) {
    var filled = 0;
    const total = 10;

    if (profile.name.isNotEmpty) filled++;
    if (profile.nickname.isNotEmpty) filled++;
    if (profile.occupation.isNotEmpty) filled++;
    if (profile.company.isNotEmpty) filled++;
    if (profile.projects.isNotEmpty) filled++;
    if (profile.goals.isNotEmpty) filled++;
    if (profile.skills.isNotEmpty) filled++;
    if (profile.interests.isNotEmpty) filled++;
    if (profile.preferences.isNotEmpty) filled++;
    if (profile.location.isNotEmpty) filled++;

    return filled / total;
  }

  Future<String> getProfileContext() async {
    final profile = await load();
    final parts = <String>[];

    if (profile.name.isNotEmpty) parts.add('Name: ${profile.name}');
    if (profile.nickname.isNotEmpty) parts.add('Nickname: ${profile.nickname}');
    if (profile.occupation.isNotEmpty) parts.add('Occupation: ${profile.occupation}');
    if (profile.company.isNotEmpty) parts.add('Company: ${profile.company}');
    if (profile.projects.isNotEmpty) parts.add('Projects: ${profile.projects.join(", ")}');
    if (profile.goals.isNotEmpty) parts.add('Goals: ${profile.goals.join(", ")}');
    if (profile.skills.isNotEmpty) parts.add('Skills: ${profile.skills.join(", ")}');
    if (profile.interests.isNotEmpty) parts.add('Interests: ${profile.interests.join(", ")}');
    if (profile.location.isNotEmpty) parts.add('Location: ${profile.location}');
    if (profile.bio.isNotEmpty) parts.add('Bio: ${profile.bio}');

    if (parts.isEmpty) return '';

    return 'USER PROFILE:\n${parts.map((p) => '  $p').join("\n")}';
  }

  Future<void> deleteProfile() async {
    if (_userId.isEmpty) return;
    final db = await database;
    await db.delete('user_profiles', where: 'user_id = ?', whereArgs: [_userId]);
    _cachedProfile = null;
  }

  void dispose() {
    _database?.close();
    _database = null;
  }
}
