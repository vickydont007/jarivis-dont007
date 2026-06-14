import 'dart:async';
import 'dart:io';
import '../models/activity_event.dart';
import '../services/timeline_service.dart';
import '../services/orb_state_manager.dart';

enum DesktopActionType {
  openFile,
  openFolder,
  openUrl,
  openApp,
  screenshot,
  clipboard,
  systemInfo,
  fileOperation,
}

class DesktopAction {
  final String id;
  final DesktopActionType type;
  final String title;
  final String description;
  final Map<String, dynamic> params;
  final DateTime createdAt;

  const DesktopAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.params = const {},
    required this.createdAt,
  });
}

class DesktopActionResult {
  final bool success;
  final dynamic data;
  final String? error;
  final Duration executionTime;

  const DesktopActionResult({
    required this.success,
    this.data,
    this.error,
    required this.executionTime,
  });
}

class DesktopActionFramework {
  final TimelineService _timeline;
  final OrbStateManager _orb;
  final List<DesktopAction> _actionHistory = [];

  DesktopActionFramework({
    required TimelineService timeline,
    required OrbStateManager orb,
  })  : _timeline = timeline,
        _orb = orb;

  List<DesktopAction> get history => List.unmodifiable(_actionHistory);

  Future<DesktopActionResult> execute({
    required DesktopActionType type,
    required String title,
    required String description,
    Map<String, dynamic> params = const {},
  }) async {
    final action = DesktopAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      description: description,
      params: params,
      createdAt: DateTime.now(),
    );

    _actionHistory.insert(0, action);
    if (_actionHistory.length > 50) {
      _actionHistory.removeRange(50, _actionHistory.length);
    }

    _orb.requestThinking('desktop');
    final stopwatch = Stopwatch()..start();

    await _timeline.log(
      source: 'Desktop',
      type: ActivityType.desktopActionExecuted,
      title: title,
      description: description,
      metadata: {'actionType': type.name, 'params': params},
    );

    try {
      final result = await _executeAction(type, params);
      stopwatch.stop();

      _orb.releaseThinking('desktop');

      await _timeline.log(
        source: 'Desktop',
        type: ActivityType.desktopActionExecuted,
        title: '$title - Success',
        description: 'Completed in ${stopwatch.elapsedMilliseconds}ms',
        metadata: {'actionType': type.name, 'success': true},
      );

      return DesktopActionResult(
        success: true,
        data: result,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      _orb.releaseThinking('desktop');

      await _timeline.log(
        source: 'Desktop',
        type: ActivityType.desktopActionExecuted,
        title: '$title - Failed',
        description: e.toString(),
        metadata: {'actionType': type.name, 'success': false, 'error': e.toString()},
      );

      return DesktopActionResult(
        success: false,
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<dynamic> _executeAction(
    DesktopActionType type,
    Map<String, dynamic> params,
  ) async {
    switch (type) {
      case DesktopActionType.openFile:
        return _openFile(params['path'] as String);
      case DesktopActionType.openFolder:
        return _openFolder(params['path'] as String);
      case DesktopActionType.openUrl:
        return _openUrl(params['url'] as String);
      case DesktopActionType.openApp:
        return _openApp(params['appName'] as String);
      case DesktopActionType.screenshot:
        return _takeScreenshot();
      case DesktopActionType.clipboard:
        return _getClipboard();
      case DesktopActionType.systemInfo:
        return _getSystemInfo();
      case DesktopActionType.fileOperation:
        return _fileOperation(params);
    }
  }

  Future<bool> _openFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await Process.run('open', [path]);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to open file: $e');
    }
  }

  Future<bool> _openFolder(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await Process.run('open', [path]);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to open folder: $e');
    }
  }

  Future<bool> _openUrl(String url) async {
    try {
      await Process.run('open', [url]);
      return true;
    } catch (e) {
      throw Exception('Failed to open URL: $e');
    }
  }

  Future<bool> _openApp(String appName) async {
    try {
      final result = await Process.run('open', ['-a', appName]);
      return result.exitCode == 0;
    } catch (e) {
      throw Exception('Failed to open app: $e');
    }
  }

  Future<String> _takeScreenshot() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '/tmp/screenshot_$timestamp.png';
      await Process.run('screencapture', ['-x', path]);
      return path;
    } catch (e) {
      throw Exception('Failed to take screenshot: $e');
    }
  }

  Future<String> _getClipboard() async {
    try {
      final result = await Process.run('pbpaste', []);
      return result.stdout.toString();
    } catch (e) {
      throw Exception('Failed to get clipboard: $e');
    }
  }

  Future<Map<String, dynamic>> _getSystemInfo() async {
    try {
      final result = await Process.run('system_profiler', ['SPHardwareDataType']);
      return {'raw': result.stdout.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<dynamic> _fileOperation(Map<String, dynamic> params) async {
    final operation = params['operation'] as String;
    final path = params['path'] as String;

    switch (operation) {
      case 'exists':
        return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
      case 'delete':
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.file) {
          await File(path).delete();
        } else if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        }
        return true;
      case 'copy':
        final dest = params['destination'] as String;
        await Process.run('cp', ['-r', path, dest]);
        return true;
      case 'move':
        final dest = params['destination'] as String;
        await Process.run('mv', [path, dest]);
        return true;
      case 'list':
        final dir = Directory(path);
        final entities = await dir.list().toList();
        return entities.map((e) => e.path).toList();
      default:
        throw Exception('Unknown file operation: $operation');
    }
  }

  Map<String, dynamic> getStats() {
    return {
      'totalActions': _actionHistory.length,
      'byType': _getActionsByType(),
    };
  }

  Map<String, int> _getActionsByType() {
    final byType = <String, int>{};
    for (final action in _actionHistory) {
      final type = action.type.name;
      byType[type] = (byType[type] ?? 0) + 1;
    }
    return byType;
  }

  void clearHistory() {
    _actionHistory.clear();
  }
}
