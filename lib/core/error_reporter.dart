import 'dart:io';
import 'package:path/path.dart' as p;

class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._();
  factory ErrorReporter() => _instance;
  ErrorReporter._();

  List<Map<String, dynamic>> _errors = [];
  static const int _maxErrors = 100;

  Future<void> logError(String message, {String? stackTrace, String? source}) async {
    final error = {
      'timestamp': DateTime.now().toIso8601String(),
      'message': message,
      'stackTrace': stackTrace,
      'source': source,
    };

    _errors.insert(0, error);
    if (_errors.length > _maxErrors) {
      _errors = _errors.sublist(0, _maxErrors);
    }

    // Write to log file
    try {
      final home = Platform.environment['HOME'] ?? '';
      final logDir = p.join(home, '.nextron', 'logs');
      await Directory(logDir).create(recursive: true);

      final logFile = File(p.join(logDir, 'errors.log'));
      final logEntry = '${error['timestamp']} [${source ?? 'unknown'}] $message';
      if (stackTrace != null) {
        await logFile.writeAsString('$logEntry\n$stackTrace\n\n', mode: FileMode.append);
      } else {
        await logFile.writeAsString('$logEntry\n\n', mode: FileMode.append);
      }
    } catch (_) {
      // Silent fail for logging
    }
  }

  List<Map<String, dynamic>> getRecentErrors({int count = 10}) {
    return _errors.take(count).toList();
  }

  void clearErrors() {
    _errors.clear();
  }

  String formatError(dynamic error, {String? context}) {
    if (error is Exception) {
      return 'Error${context != null ? ' in $context' : ''}: ${error.toString()}';
    }
    return 'Error${context != null ? ' in $context' : ''}: $error';
  }

  String get userFriendlyMessage {
    if (_errors.isEmpty) return 'No errors';
    final latest = _errors.first;
    final msg = latest['message'] as String;

    if (msg.contains('Permission denied')) {
      return 'Permission denied. Check System Settings > Privacy & Security.';
    }
    if (msg.contains('Connection refused') || msg.contains('SocketException')) {
      return 'Connection failed. Check your internet connection.';
    }
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('API key') || msg.contains('401')) {
      return 'Invalid API key. Check Settings > API Key.';
    }
    if (msg.contains('Rate limit') || msg.contains('429')) {
      return 'Too many requests. Please wait a moment.';
    }

    return msg;
  }
}
