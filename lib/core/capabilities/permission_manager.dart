import 'dart:async';
import 'tool_registry.dart';

enum PermissionAction {
  granted,
  denied,
  prompt,
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
  final Map<String, PermissionLevel> _grantedPermissions = {};
  final Map<String, PermissionLevel> _toolPermissions = {};
  final List<PermissionRule> _rules = [];
  final List<PermissionRequest> _requests = [];
  final StreamController<PermissionRequest> _requestController =
      StreamController<PermissionRequest>.broadcast();

  Stream<PermissionRequest> get requests => _requestController.stream;

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

  PermissionLevel getEffectiveLevel(String toolName) {
    // Check explicit grant first
    final granted = _grantedPermissions[toolName];
    if (granted != null) return granted;

    // Check tool default
    final toolDefault = _toolPermissions[toolName];
    if (toolDefault != null) return toolDefault;

    // Check pattern rules
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

  Future<PermissionRequest> requestPermission({
    required String toolName,
    required PermissionLevel level,
  }) async {
    // Check if already granted
    if (hasPermission(toolName, level)) {
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

    // Check auto-grant rules
    for (final rule in _rules) {
      if (_matchesPattern(toolName, rule.pattern) && rule.autoGrant) {
        if (rule.level.index >= level.index) {
          grantPermission(toolName, rule.level);
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

    // Create pending request
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

  void resolveRequest(String requestId, PermissionAction action) {
    final request = _requests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => throw Exception('Request not found'),
    );
    request.action = action;
    request.resolvedAt = DateTime.now();

    if (action == PermissionAction.granted) {
      grantPermission(request.toolName, request.requestedLevel);
    }
  }

  List<PermissionRequest> getPendingRequests() {
    return _requests.where((r) => r.isPending).toList();
  }

  Map<String, PermissionLevel> getAllGranted() {
    return Map.unmodifiable(_grantedPermissions);
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
    };
  }

  void dispose() {
    _requestController.close();
  }
}
