import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'platform.dart';

enum LogLevel { debug, info, warning, error }

class JarvisLogger {
  static final JarvisLogger _instance = JarvisLogger._internal();
  factory JarvisLogger() => _instance;
  JarvisLogger._internal();

  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _streamController =
      StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get logStream => _streamController.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  String _logFile = '';
  IOSink? _fileSink;

  Future<void> init() async {
    final dir = Directory(PlatformInfo.configDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _logFile = p.join(PlatformInfo.configDir, 'jarvis.log');
    _fileSink = File(_logFile).openWrite(mode: FileMode.append);

    info('Logger initialized | Platform: ${PlatformInfo.current.name}');
  }

  void debug(String message, {Map<String, dynamic>? data}) =>
      _log(LogLevel.debug, message, data);
  void info(String message, {Map<String, dynamic>? data}) =>
      _log(LogLevel.info, message, data);
  void warning(String message, {Map<String, dynamic>? data}) =>
      _log(LogLevel.warning, message, data);
  void error(String message, {Map<String, dynamic>? data, Object? exception}) =>
      _log(LogLevel.error, message, data, exception: exception);

  void _log(LogLevel level, String message, Map<String, dynamic>? data,
      {Object? exception}) {
    final entry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      timestamp: DateTime.now(),
      level: level,
      message: message,
      data: data,
      exception: exception?.toString(),
    );

    _logs.add(entry);
    _streamController.add(entry);

    // Console output
    final prefix = '[${entry.timestamp.toIso8601String()}] [${level.name.toUpperCase()}]';
    if (level == LogLevel.error) {
      stderr.writeln('$prefix $message');
      if (exception != null) stderr.writeln('  └─ $exception');
    } else {
      stdout.writeln('$prefix $message');
    }

    // File output
    _writeToFile(entry);
  }

  void _writeToFile(LogEntry entry) {
    try {
      final jsonLine = jsonEncode({
        'timestamp': entry.timestamp.toIso8601String(),
        'level': entry.level.name,
        'message': entry.message,
        'data': entry.data,
        'exception': entry.exception,
      });
      _fileSink?.writeln(jsonLine);
    } catch (_) {}
  }

  Future<List<String>> getRecentLogs({int count = 100}) async {
    try {
      final file = File(_logFile);
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      return lines.reversed.take(count).toList().reversed.toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _fileSink?.close();
    _streamController.close();
  }
}

class LogEntry {
  final int id;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic>? data;
  final String? exception;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.data,
    this.exception,
  });
}
