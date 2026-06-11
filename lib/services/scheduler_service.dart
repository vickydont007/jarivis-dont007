import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../core/logger.dart';
import '../core/platform.dart';

class SchedulerService {
  static final SchedulerService _instance = SchedulerService._internal();
  factory SchedulerService() => _instance;
  SchedulerService._internal();

  final JarvisLogger _log = JarvisLogger();
  final List<ScheduledTask> _tasks = [];
  Timer? _checkTimer;
  final StreamController<ScheduledTask> _taskTriggeredController =
      StreamController<ScheduledTask>.broadcast();

  Stream<ScheduledTask> get onTaskTriggered => _taskTriggeredController.stream;
  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);

  Future<void> init() async {
    await _loadTasks();
    _startChecker();
    _log.info('Scheduler initialized with ${_tasks.length} tasks');
  }

  void _startChecker() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkScheduled(),
    );
  }

  Future<void> schedule({
    required String id,
    required String title,
    required String command,
    required String cronExpression,
    Map<String, dynamic>? metadata,
  }) async {
    final task = ScheduledTask(
      id: id,
      title: title,
      command: command,
      cronExpression: cronExpression,
      metadata: metadata,
    );
    
    _tasks.add(task);
    await _saveTasks();
    _log.info('Scheduled task: $title [$cronExpression]');
  }

  Future<void> remove(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _saveTasks();
  }

  void _checkScheduled() {
    final now = DateTime.now();
    for (final task in _tasks) {
      if (!task.enabled) continue;
      if (_matchesCron(task.cronExpression, now)) {
        _log.info('Task triggered: ${task.title}');
        _taskTriggeredController.add(task);
      }
    }
  }

  bool _matchesCron(String expression, DateTime now) {
    // Simple cron parser: minute hour day month weekday
    // Supports: * (every), numbers, comma lists
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length < 5) return false;

    final minute = parts[0];
    final hour = parts[1];
    final day = parts[2];
    final month = parts[3];

    return _cronMatches(minute, now.minute) &&
        _cronMatches(hour, now.hour) &&
        _cronMatches(day, now.day) &&
        _cronMatches(month, now.month);
  }

  bool _cronMatches(String pattern, int value) {
    if (pattern == '*') return true;
    if (pattern.contains(',')) {
      return pattern.split(',').any((p) => _cronMatches(p.trim(), value));
    }
    if (pattern.contains('-')) {
      final range = pattern.split('-');
      final low = int.tryParse(range[0]) ?? 0;
      final high = int.tryParse(range[1]) ?? 59;
      return value >= low && value <= high;
    }
    if (pattern.contains('/')) {
      final parts = pattern.split('/');
      final step = int.tryParse(parts[1]) ?? 1;
      if (parts[0] == '*') return value % step == 0;
      final start = int.tryParse(parts[0]) ?? 0;
      return (value - start) % step == 0;
    }
    final numVal = int.tryParse(pattern);
    return numVal != null && numVal == value;
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('scheduled_tasks');
      if (tasksJson != null) {
        final list = jsonDecode(tasksJson) as List;
        _tasks.addAll(list.map((e) => ScheduledTask.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      _log.error('Failed to load tasks', exception: e);
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString('scheduled_tasks', tasksJson);
    } catch (e) {
      _log.error('Failed to save tasks', exception: e);
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _taskTriggeredController.close();
  }
}

class ScheduledTask {
  final String id;
  final String title;
  final String command;
  final String cronExpression;
  final bool enabled;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ScheduledTask({
    required this.id,
    required this.title,
    required this.command,
    required this.cronExpression,
    this.enabled = true,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  ScheduledTask copyWith({bool? enabled}) => ScheduledTask(
    id: id,
    title: title,
    command: command,
    cronExpression: cronExpression,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
    metadata: metadata,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'command': command,
    'cronExpression': cronExpression,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'metadata': metadata,
  };

  factory ScheduledTask.fromJson(Map<String, dynamic> json) => ScheduledTask(
    id: json['id'] as String,
    title: json['title'] as String,
    command: json['command'] as String,
    cronExpression: json['cronExpression'] as String,
    enabled: json['enabled'] as bool? ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}
