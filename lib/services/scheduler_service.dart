import 'dart:async';
import 'package:uuid/uuid.dart';

enum ScheduleType {
  once,
  daily,
  weekly,
  monthly,
  custom,
}

enum ScheduleStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

class Schedule {
  final String id;
  final String name;
  final String description;
  final ScheduleType type;
  final ScheduleStatus status;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final String? cronExpression;
  final Map<String, dynamic> payload;
  final int repeatCount;
  final int currentRepeat;

  Schedule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.status = ScheduleStatus.pending,
    required this.createdAt,
    this.scheduledAt,
    this.completedAt,
    this.cronExpression,
    this.payload = const {},
    this.repeatCount = 1,
    this.currentRepeat = 0,
  });

  factory Schedule.create({
    required String name,
    required String description,
    required ScheduleType type,
    DateTime? scheduledAt,
    String? cronExpression,
    Map<String, dynamic> payload = const {},
    int repeatCount = 1,
  }) {
    return Schedule(
      id: const Uuid().v4(),
      name: name,
      description: description,
      type: type,
      scheduledAt: scheduledAt,
      cronExpression: cronExpression,
      payload: payload,
      repeatCount: repeatCount,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cron_expression': cronExpression,
      'payload': payload,
      'repeat_count': repeatCount,
      'current_repeat': currentRepeat,
    };
  }
}

class SchedulerService {
  final List<Schedule> _schedules = [];
  final Map<String, Timer> _timers = {};
  final StreamController<Schedule> _scheduleController =
      StreamController<Schedule>.broadcast();

  Stream<Schedule> get scheduleStream => _scheduleController.stream;
  List<Schedule> get schedules => List.unmodifiable(_schedules);

  SchedulerService() {
    _startScheduler();
  }

  void _startScheduler() {
    // Check for due schedules every minute
    Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkDueSchedules();
    });
  }

  void _checkDueSchedules() {
    final now = DateTime.now();

    for (final schedule in _schedules) {
      if (schedule.status == ScheduleStatus.pending &&
          schedule.scheduledAt != null &&
          schedule.scheduledAt!.isBefore(now)) {
        _executeSchedule(schedule);
      }
    }
  }

  Future<void> _executeSchedule(Schedule schedule) async {
    // Update status
    final runningSchedule = Schedule(
      id: schedule.id,
      name: schedule.name,
      description: schedule.description,
      type: schedule.type,
      status: ScheduleStatus.running,
      createdAt: schedule.createdAt,
      scheduledAt: schedule.scheduledAt,
      cronExpression: schedule.cronExpression,
      payload: schedule.payload,
      repeatCount: schedule.repeatCount,
      currentRepeat: schedule.currentRepeat,
    );

    _updateSchedule(runningSchedule);
    _scheduleController.add(runningSchedule);

    try {
      // Execute the scheduled task
      await _executeTask(schedule);

      // Update status to completed
      final completedSchedule = Schedule(
        id: schedule.id,
        name: schedule.name,
        description: schedule.description,
        type: schedule.type,
        status: ScheduleStatus.completed,
        createdAt: schedule.createdAt,
        scheduledAt: schedule.scheduledAt,
        completedAt: DateTime.now(),
        cronExpression: schedule.cronExpression,
        payload: schedule.payload,
        repeatCount: schedule.repeatCount,
        currentRepeat: schedule.currentRepeat + 1,
      );

      _updateSchedule(completedSchedule);
      _scheduleController.add(completedSchedule);

      // Schedule next repeat if needed
      if (completedSchedule.currentRepeat < completedSchedule.repeatCount) {
        _scheduleNextRepeat(completedSchedule);
      }
    } catch (e) {
      // Update status to failed
      final failedSchedule = Schedule(
        id: schedule.id,
        name: schedule.name,
        description: schedule.description,
        type: schedule.type,
        status: ScheduleStatus.failed,
        createdAt: schedule.createdAt,
        scheduledAt: schedule.scheduledAt,
        completedAt: DateTime.now(),
        cronExpression: schedule.cronExpression,
        payload: schedule.payload,
        repeatCount: schedule.repeatCount,
        currentRepeat: schedule.currentRepeat,
      );

      _updateSchedule(failedSchedule);
      _scheduleController.add(failedSchedule);
    }
  }

  Future<void> _executeTask(Schedule schedule) async {
    final action = schedule.payload['action'] as String?;
    final params = schedule.payload['params'] as Map<String, dynamic>?;

    switch (action) {
      case 'notification':
        // TODO: Show notification
        break;
      case 'system':
        // Execute system command
        final command = params?['command'] as String?;
        if (command != null) {
          // System commands handled elsewhere
        }
        break;
      case 'ai':
        // Execute AI task
        final prompt = params?['prompt'] as String?;
        if (prompt != null) {
          // AI task handled elsewhere
        }
        break;
      case 'file':
        // Execute file operation
        final operation = params?['operation'] as String?;
        final path = params?['path'] as String?;
        if (operation != null && path != null) {
          // File operations handled elsewhere
        }
        break;
      default:
        // Default task execution
        break;
    }
  }

  void _scheduleNextRepeat(Schedule schedule) {
    DateTime? nextScheduledAt;

    switch (schedule.type) {
      case ScheduleType.daily:
        nextScheduledAt = schedule.scheduledAt?.add(const Duration(days: 1));
        break;
      case ScheduleType.weekly:
        nextScheduledAt = schedule.scheduledAt?.add(const Duration(days: 7));
        break;
      case ScheduleType.monthly:
        nextScheduledAt = schedule.scheduledAt?.add(const Duration(days: 30));
        break;
      default:
        break;
    }

    if (nextScheduledAt != null) {
      final nextSchedule = Schedule(
        id: const Uuid().v4(),
        name: schedule.name,
        description: schedule.description,
        type: schedule.type,
        scheduledAt: nextScheduledAt,
        cronExpression: schedule.cronExpression,
        payload: schedule.payload,
        repeatCount: schedule.repeatCount,
        currentRepeat: schedule.currentRepeat,
        createdAt: DateTime.now(),
      );

      _schedules.add(nextSchedule);
      _scheduleController.add(nextSchedule);
    }
  }

  void _updateSchedule(Schedule schedule) {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
    }
  }

  // Create schedule from natural language
  Schedule createFromNaturalLanguage(String input) {
    final lowerInput = input.toLowerCase();
    ScheduleType type = ScheduleType.once;
    DateTime? scheduledAt;

    // Parse schedule type
    if (lowerInput.contains('daily') || lowerInput.contains('every day')) {
      type = ScheduleType.daily;
      scheduledAt = DateTime.now().add(const Duration(hours: 1));
    } else if (lowerInput.contains('weekly') || lowerInput.contains('every week')) {
      type = ScheduleType.weekly;
      scheduledAt = DateTime.now().add(const Duration(days: 1));
    } else if (lowerInput.contains('monthly') || lowerInput.contains('every month')) {
      type = ScheduleType.monthly;
      scheduledAt = DateTime.now().add(const Duration(days: 30));
    } else {
      // Parse specific time
      final timeMatch = RegExp(r'at (\d{1,2}):?(\d{0,2})').firstMatch(lowerInput);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2) ?? '0');
        scheduledAt = DateTime.now();
        scheduledAt = scheduledAt.add(Duration(
          hours: hour - scheduledAt.hour,
          minutes: minute - scheduledAt.minute,
        ));
      }
    }

    return Schedule.create(
      name: 'Scheduled Task',
      description: input,
      type: type,
      scheduledAt: scheduledAt,
    );
  }

  // Add schedule
  void addSchedule(Schedule schedule) {
    _schedules.add(schedule);
    _scheduleController.add(schedule);

    // Set timer if scheduled
    if (schedule.scheduledAt != null) {
      final duration = schedule.scheduledAt!.difference(DateTime.now());
      if (duration.isNegative) return;

      _timers[schedule.id] = Timer(duration, () {
        _executeSchedule(schedule);
      });
    }
  }

  // Cancel schedule
  void cancelSchedule(String scheduleId) {
    _timers[scheduleId]?.cancel();
    _timers.remove(scheduleId);

    final index = _schedules.indexWhere((s) => s.id == scheduleId);
    if (index != -1) {
      final cancelledSchedule = Schedule(
        id: _schedules[index].id,
        name: _schedules[index].name,
        description: _schedules[index].description,
        type: _schedules[index].type,
        status: ScheduleStatus.cancelled,
        createdAt: _schedules[index].createdAt,
        scheduledAt: _schedules[index].scheduledAt,
        cronExpression: _schedules[index].cronExpression,
        payload: _schedules[index].payload,
        repeatCount: _schedules[index].repeatCount,
        currentRepeat: _schedules[index].currentRepeat,
      );

      _schedules[index] = cancelledSchedule;
      _scheduleController.add(cancelledSchedule);
    }
  }

  // Get pending schedules
  List<Schedule> getPendingSchedules() {
    return _schedules
        .where((s) => s.status == ScheduleStatus.pending)
        .toList();
  }

  // Get completed schedules
  List<Schedule> getCompletedSchedules() {
    return _schedules
        .where((s) => s.status == ScheduleStatus.completed)
        .toList();
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _scheduleController.close();
  }
}
