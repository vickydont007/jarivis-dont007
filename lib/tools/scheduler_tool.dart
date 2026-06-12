import 'tool.dart';
import '../services/scheduler_service.dart';

class SchedulerCreateTool extends Tool {
  final SchedulerService _service;

  SchedulerCreateTool(this._service)
      : super(
          name: 'scheduler_create',
          description: 'Create a scheduled task',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Task name',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'description',
              description: 'Task description',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'type',
              description: 'Schedule type: once, daily, weekly, monthly',
              type: ToolParameterType.string,
              required: true,
              enumValues: ['once', 'daily', 'weekly', 'monthly'],
            ),
            const ToolParameter(
              name: 'scheduled_at',
              description: 'ISO8601 datetime for when to run (for "once")',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'cron_expression',
              description: 'Cron expression (for daily/weekly/monthly)',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'action',
              description: 'Action to perform (e.g., "notification", "system")',
              type: ToolParameterType.string,
              defaultValue: 'notification',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String;
    final description = params['description'] as String;
    final typeStr = params['type'] as String;
    final scheduledAtStr = params['scheduled_at'] as String?;
    final cronExpression = params['cron_expression'] as String?;
    final action = params['action'] as String? ?? 'notification';

    final type = ScheduleType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ScheduleType.once,
    );

    DateTime? scheduledAt;
    if (scheduledAtStr != null) {
      scheduledAt = DateTime.tryParse(scheduledAtStr);
    }

    try {
      final schedule = Schedule.create(
        name: name,
        description: description,
        type: type,
        scheduledAt: scheduledAt,
        cronExpression: cronExpression,
        payload: {'action': action},
      );
      _service.addSchedule(schedule);
      return ToolResult.success('Schedule created: ${schedule.id}', metadata: {
        'id': schedule.id,
        'name': name,
        'type': typeStr,
      });
    } catch (e) {
      return ToolResult.error('Failed to create schedule: $e');
    }
  }
}

class SchedulerListTool extends Tool {
  final SchedulerService _service;

  SchedulerListTool(this._service)
      : super(
          name: 'scheduler_list',
          description: 'List scheduled tasks',
          parameters: [
            const ToolParameter(
              name: 'status',
              description: 'Filter by status: pending, completed, all',
              type: ToolParameterType.string,
              defaultValue: 'all',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final status = params['status'] as String? ?? 'all';
    try {
      List<Schedule> schedules;
      if (status == 'pending') {
        schedules = _service.getPendingSchedules();
      } else if (status == 'completed') {
        schedules = _service.getCompletedSchedules();
      } else {
        schedules = _service.schedules;
      }
      final data = schedules.map((s) => s.toMap()).toList();
      return ToolResult.success(data, metadata: {'count': data.length});
    } catch (e) {
      return ToolResult.error('Failed to list schedules: $e');
    }
  }
}

class SchedulerCancelTool extends Tool {
  final SchedulerService _service;

  SchedulerCancelTool(this._service)
      : super(
          name: 'scheduler_cancel',
          description: 'Cancel a scheduled task',
          parameters: [
            const ToolParameter(
              name: 'schedule_id',
              description: 'ID of the schedule to cancel',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final scheduleId = params['schedule_id'] as String;
    try {
      _service.cancelSchedule(scheduleId);
      return ToolResult.success('Schedule cancelled: $scheduleId');
    } catch (e) {
      return ToolResult.error('Failed to cancel schedule: $e');
    }
  }
}

List<Tool> getAllSchedulerTools(SchedulerService service) {
  return [
    SchedulerCreateTool(service),
    SchedulerListTool(service),
    SchedulerCancelTool(service),
  ];
}
