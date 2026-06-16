import 'dart:io';
import 'package:path/path.dart' as p;

enum PermissionAction { read, write, delete, move, create }

class FilePermissionResult {
  final bool allowed;
  final String? reason;
  final String? suggestedPath;

  FilePermissionResult({
    required this.allowed,
    this.reason,
    this.suggestedPath,
  });
}

class FilePermissionManager {
  static final FilePermissionManager _instance = FilePermissionManager._();
  factory FilePermissionManager() => _instance;
  FilePermissionManager._();

  final String _home = Platform.environment['HOME'] ?? '';

  final List<String> _blockedPaths = [
    '/System',
    '/usr',
    '/bin',
    '/sbin',
    '/private/var',
    '/private/etc',
    '/private/tmp',
    '/Library/LaunchDaemons',
    '/Library/LaunchAgents',
  ];

  List<String> get allowedBasePaths => [
        _home,
        '$_home/Desktop',
        '$_home/Documents',
        '$_home/Downloads',
        '$_home/Movies',
        '$_home/Music',
        '$_home/Pictures',
      ];

  FilePermissionResult checkPermission(String path, PermissionAction action) {
    final normalized = p.normalize(path);

    if (_isBlocked(normalized)) {
      return FilePermissionResult(
        allowed: false,
        reason: 'Access to system directory is blocked: $normalized',
        suggestedPath: '$_home/Documents',
      );
    }

    if (!_isWithinSandbox(normalized)) {
      return FilePermissionResult(
        allowed: false,
        reason: 'Path is outside allowed directory: $normalized',
        suggestedPath: _suggestAlternative(normalized),
      );
    }

    if (action == PermissionAction.delete ||
        action == PermissionAction.move) {
      if (_isProtectedPath(normalized)) {
        return FilePermissionResult(
          allowed: false,
          reason:
              'Cannot delete or move protected directory: ${p.basename(normalized)}',
          suggestedPath: null,
        );
      }
    }

    return FilePermissionResult(allowed: true);
  }

  bool _isBlocked(String path) {
    for (final blocked in _blockedPaths) {
      if (path == blocked || path.startsWith('$blocked/')) {
        return true;
      }
    }
    return false;
  }

  bool _isWithinSandbox(String path) {
    if (path.startsWith(_home)) return true;
    if (path.startsWith('/tmp')) return true;
    if (path.contains('com.nextron.ai')) return true;
    return false;
  }

  bool _isProtectedPath(String path) {
    final protected = [
      _home,
      '$_home/Desktop',
      '$_home/Documents',
      '$_home/Downloads',
    ];
    return protected.contains(path);
  }

  String _suggestAlternative(String path) {
    if (path.contains('Desktop')) return '$_home/Desktop';
    if (path.contains('Documents')) return '$_home/Documents';
    if (path.contains('Downloads')) return '$_home/Downloads';
    return '$_home/Documents';
  }

  String resolvePath(String requestedPath) {
    final normalized = p.normalize(requestedPath);

    if (_isWithinSandbox(normalized)) return normalized;

    return _suggestAlternative(normalized);
  }

  bool get isSandboxed => _home.isNotEmpty;
}
