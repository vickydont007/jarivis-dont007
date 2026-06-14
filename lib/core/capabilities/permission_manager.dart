import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tool_registry.dart';

enum PermissionAction {
  granted,
  denied,
  prompt,
}

enum PermissionPolicy {
  allowOnce,
  alwaysAllow,
  deny,
}

class PermissionRequest {
  final String id;
  final String toolName;
  final PermissionLevel requestedLevel;
  final DateTime requestedAt;
  PermissionAction? action;
  DateTime? resolvedAt;

  PermissionRequest({
    required this.id,
    required this.toolName,
    required this.requestedLevel,
    required this.requestedAt,
  });

  bool get isPending => action == null;
  bool get isGranted => action == PermissionAction.granted;
  bool get isDenied => action == PermissionAction.denied;
}

class PermissionRule {
  final String pattern;
  final PermissionLevel level;
  final bool autoGrant;

  const PermissionRule({
    required this.pattern,
    required this.level,
    this.autoGrant = false,
  });
}

class PermissionManager {
  static Database? _database;
  static const _dbName = 'nextron_permissions.db';

  final Map<String, PermissionLevel> _grantedPermissions = {};
  final Map<String, PermissionLevel> _toolPermissions = {};
  final Map<String, PermissionPolicy> _toolPolicies = {};
  final List<PermissionRule> _rules = [];
  final List<PermissionRequest> _requests = [];
  final StreamController<PermissionRequest> _requestController =
      StreamController<PermissionRequest>.broadcast();
  final StreamController<Map<String, PermissionPolicy>> _policyController =
      StreamController<Map<String, PermissionPolicy>>.broadcast();

  Stream<PermissionRequest> get requests => _requestController.stream;
  Stream<Map<String, PermissionPolicy>> get policyUpdates => _policyController.stream;

  Future<void> initialize() async {
    await _initDatabase();
    await _loadPolicies();
    await _loadRules();
  }

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
          CREATE TABLE tool_policies (
            tool_name TEXT PRIMARY KEY,
            policy TEXT NOT NULL,
            permission_level TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE permission_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pattern TEXT NOT NULL,
            level TEXT NOT NULL,
            auto_grant INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE permission_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tool_name TEXT NOT NULL,
            action TEXT NOT NULL,
            policy TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> _loadPolicies() async {
    final db = await database;
    final results = await db.query('tool_policies');
    for (final row in results) {
      final toolName = row['tool_name'] as String;
      final policy = PermissionPolicy.values.firstWhere(
        (p) => p.name == row['policy'],
      );
      final level = PermissionLevel.values.firstWhere(
        (l) => l.name == row['permission_level'],
      );
      _toolPolicies[toolName] = policy;
      _toolPermissions[toolName] = level;
      if (policy == PermissionPolicy.alwaysAllow) {
        _grantedPermissions[toolName] = level;
      }
    }
  }

  Future<void> _loadRules() async {
    final db = await database;
    final results = await db.query('permission_rules');
    for (final row in results) {
      _rules.add(PermissionRule(
        pattern: row['pattern'] as String,
        level: PermissionLevel.values.firstWhere(
          (l) => l.name == row['level'],
        ),
        autoGrant: (row['auto_grant'] as int) == 1,
      ));
    }
  }

  void setToolPermission(String toolName, PermissionLevel level) {
    _toolPermissions[toolName] = level;
  }

  void grantPermission(String toolName, PermissionLevel level) {
    _grantedPermissions[toolName] = level;
  }

  void revokePermission(String toolName) {
    _grantedPermissions.remove(toolName);
  }

  void addRule(PermissionRule rule) {
    _rules.add(rule);
  }

  Future<void> setToolPolicy(String toolName, PermissionPolicy policy, PermissionLevel level) async {
    _toolPolicies[toolName] = policy;
    _toolPermissions[toolName] = level;

    if (policy == PermissionPolicy.alwaysAllow) {
      _grantedPermissions[toolName] = level;
    } else {
      _grantedPermissions.remove(toolName);
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'tool_policies',
      {
        'tool_name': toolName,
        'policy': policy.name,
        'permission_level': level.name,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _policyController.add(Map.unmodifiable(_toolPolicies));
  }

  PermissionPolicy? getToolPolicy(String toolName) {
    return _toolPolicies[toolName];
  }

  Map<String, PermissionPolicy> getAllPolicies() {
    return Map.unmodifiable(_toolPolicies);
  }

  PermissionLevel getEffectiveLevel(String toolName) {
    final granted = _grantedPermissions[toolName];
    if (granted != null) return granted;

    final toolDefault = _toolPermissions[toolName];
    if (toolDefault != null) return toolDefault;

    for (final rule in _rules) {
      if (_matchesPattern(toolName, rule.pattern)) {
        return rule.level;
      }
    }

    return PermissionLevel.none;
  }

  bool hasPermission(String toolName, PermissionLevel required) {
    final effective = getEffectiveLevel(toolName);
    return effective.index >= required.index;
  }

  bool canExecute(String toolName, ToolDefinition definition) {
    return hasPermission(toolName, definition.requiredPermission);
  }

  Future<void> _logPermission(String toolName, String action, String policy) async {
    final db = await database;
    await db.insert('permission_log', {
      'tool_name': toolName,
      'action': action,
      'policy': policy,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<PermissionRequest> requestPermission({
    required String toolName,
    required PermissionLevel level,
  }) async {
    if (hasPermission(toolName, level)) {
      final policy = _toolPolicies[toolName];
      await _logPermission(toolName, 'auto_granted', policy?.name ?? 'default');
      final request = PermissionRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: toolName,
        requestedLevel: level,
        requestedAt: DateTime.now(),
      );
      request.action = PermissionAction.granted;
      request.resolvedAt = DateTime.now();
      return request;
    }

    for (final rule in _rules) {
      if (_matchesPattern(toolName, rule.pattern) && rule.autoGrant) {
        if (rule.level.index >= level.index) {
          grantPermission(toolName, rule.level);
          await _logPermission(toolName, 'rule_granted', 'rule:${rule.pattern}');
          final request = PermissionRequest(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            toolName: toolName,
            requestedLevel: level,
            requestedAt: DateTime.now(),
          );
          request.action = PermissionAction.granted;
          request.resolvedAt = DateTime.now();
          return request;
        }
      }
    }

    final request = PermissionRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      toolName: toolName,
      requestedLevel: level,
      requestedAt: DateTime.now(),
    );
    _requests.add(request);
    _requestController.add(request);
    return request;
  }

  Future<void> resolveRequest(String requestId, PermissionAction action, {bool alwaysAllow = false}) async {
    final request = _requests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => throw Exception('Request not found'),
    );
    request.action = action;
    request.resolvedAt = DateTime.now();

    if (action == PermissionAction.granted) {
      if (alwaysAllow) {
        await setToolPolicy(request.toolName, PermissionPolicy.alwaysAllow, request.requestedLevel);
        await _logPermission(request.toolName, 'always_allowed', 'user');
      } else {
        grantPermission(request.toolName, request.requestedLevel);
        await _logPermission(request.toolName, 'once_allowed', 'user');
      }
    } else {
      await setToolPolicy(request.toolName, PermissionPolicy.deny, PermissionLevel.none);
      await _logPermission(request.toolName, 'denied', 'user');
    }
  }

  List<PermissionRequest> getPendingRequests() {
    return _requests.where((r) => r.isPending).toList();
  }

  Map<String, PermissionLevel> getAllGranted() {
    return Map.unmodifiable(_grantedPermissions);
  }

  Future<List<Map<String, dynamic>>> getPermissionLog({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'permission_log',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results;
  }

  bool _matchesPattern(String toolName, String pattern) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      return toolName.startsWith(pattern.substring(0, pattern.length - 1));
    }
    if (pattern.startsWith('*')) {
      return toolName.endsWith(pattern.substring(1));
    }
    return toolName == pattern;
  }

  Map<String, dynamic> getStats() {
    return {
      'granted': _grantedPermissions.length,
      'pending': getPendingRequests().length,
      'rules': _rules.length,
      'policies': _toolPolicies.length,
      'alwaysAllow': _toolPolicies.values.where((p) => p == PermissionPolicy.alwaysAllow).length,
      'deny': _toolPolicies.values.where((p) => p == PermissionPolicy.deny).length,
    };
  }

  void dispose() {
    _requestController.close();
    _policyController.close();
  }
}
