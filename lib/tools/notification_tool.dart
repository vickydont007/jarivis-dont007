import '../core/notification_intelligence.dart';
import 'tool.dart';

List<Tool> getAllNotificationTools(NotificationIntelligence intelligence) {
  return [
    CreateNotificationRuleTool(intelligence),
    GetNotificationRulesTool(intelligence),
    RecordNotificationEventTool(intelligence),
    ToggleNotificationRuleTool(intelligence),
    DeleteNotificationRuleTool(intelligence),
    GetRecentNotificationsTool(intelligence),
    GetNotificationStatsTool(intelligence),
  ];
}

class CreateNotificationRuleTool extends Tool {
  final NotificationIntelligence _intelligence;

  CreateNotificationRuleTool(this._intelligence)
      : super(
          name: 'create_notification_rule',
          description: 'Create a rule to intelligently handle notifications.',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Name of the rule',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'description',
              description: 'Description of what the rule does',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'source_app',
              description: 'Source application (e.g., "com.apple.MobileSMS")',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'pattern',
              description: 'Pattern to match in notifications',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'action',
              description: 'Action to take when matched',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _intelligence.createRule(
      name: params['name'],
      description: params['description'],
      sourceApp: params['source_app'],
      pattern: params['pattern'],
      action: params['action'],
    );
    return ToolResult.success('Notification rule created');
  }
}

class GetNotificationRulesTool extends Tool {
  final NotificationIntelligence _intelligence;

  GetNotificationRulesTool(this._intelligence)
      : super(
          name: 'get_notification_rules',
          description: 'Get all notification rules.',
          parameters: [
            const ToolParameter(
              name: 'source_app',
              description: 'Filter by source app (optional)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final rules = await _intelligence.getRules(
      sourceApp: params['source_app'],
    );
    final data = rules.map((r) => {
      'id': r.id,
      'name': r.name,
      'description': r.description,
      'sourceApp': r.sourceApp,
      'pattern': r.pattern,
      'action': r.action,
      'enabled': r.enabled,
      'triggerCount': r.triggerCount,
    }).toList();
    return ToolResult.success(data, metadata: {'count': data.length});
  }
}

class RecordNotificationEventTool extends Tool {
  final NotificationIntelligence _intelligence;

  RecordNotificationEventTool(this._intelligence)
      : super(
          name: 'record_notification_event',
          description: 'Record a notification event.',
          parameters: [
            const ToolParameter(
              name: 'source_app',
              description: 'Source application',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'title',
              description: 'Notification title',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'body',
              description: 'Notification body',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'rule_id',
              description: 'ID of the matched rule (optional)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _intelligence.recordEvent(
      sourceApp: params['source_app'],
      title: params['title'],
      body: params['body'],
      ruleId: params['rule_id'],
    );
    return ToolResult.success('Notification event recorded');
  }
}

class ToggleNotificationRuleTool extends Tool {
  final NotificationIntelligence _intelligence;

  ToggleNotificationRuleTool(this._intelligence)
      : super(
          name: 'toggle_notification_rule',
          description: 'Enable or disable a notification rule.',
          parameters: [
            const ToolParameter(
              name: 'rule_id',
              description: 'ID of the rule to toggle',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'enabled',
              description: 'Whether the rule should be enabled',
              type: ToolParameterType.boolean,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _intelligence.toggleRule(params['rule_id'], params['enabled']);
    return ToolResult.success('Rule ${params['enabled'] ? 'enabled' : 'disabled'}');
  }
}

class DeleteNotificationRuleTool extends Tool {
  final NotificationIntelligence _intelligence;

  DeleteNotificationRuleTool(this._intelligence)
      : super(
          name: 'delete_notification_rule',
          description: 'Delete a notification rule.',
          parameters: [
            const ToolParameter(
              name: 'rule_id',
              description: 'ID of the rule to delete',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _intelligence.deleteRule(params['rule_id']);
    return ToolResult.success('Rule deleted');
  }
}

class GetRecentNotificationsTool extends Tool {
  final NotificationIntelligence _intelligence;

  GetRecentNotificationsTool(this._intelligence)
      : super(
          name: 'get_recent_notifications',
          description: 'Get recent notification events.',
          parameters: [
            const ToolParameter(
              name: 'limit',
              description: 'Maximum number of notifications to return',
              type: ToolParameterType.integer,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final events = await _intelligence.getRecentEvents(
      limit: params['limit'] ?? 50,
    );
    final data = events.map((e) => {
      'id': e.id,
      'sourceApp': e.sourceApp,
      'title': e.title,
      'body': e.body,
      'timestamp': e.timestamp.toIso8601String(),
      'processed': e.processed,
    }).toList();
    return ToolResult.success(data, metadata: {'count': data.length});
  }
}

class GetNotificationStatsTool extends Tool {
  final NotificationIntelligence _intelligence;

  GetNotificationStatsTool(this._intelligence)
      : super(
          name: 'get_notification_stats',
          description: 'Get statistics about the notification system.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final stats = await _intelligence.getStats();
    return ToolResult.success(stats);
  }
}
