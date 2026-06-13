import '../core/predictive_automation.dart';
import 'tool.dart';

List<Tool> getAllPredictiveTools(PredictiveAutomation automation) {
  return [
    CreateAutomationPatternTool(automation),
    GetPatternsByTriggerTool(automation),
    GetAllPatternsTool(automation),
    RecordAutomationEventTool(automation),
    UpdatePatternConfidenceTool(automation),
    DeletePatternTool(automation),
    GetAutomationStatsTool(automation),
  ];
}

class CreateAutomationPatternTool extends Tool {
  final PredictiveAutomation _automation;

  CreateAutomationPatternTool(this._automation)
      : super(
          name: 'create_automation_pattern',
          description: 'Create a new automation pattern for predictive automation.',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Name of the automation pattern',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'description',
              description: 'Description of what the pattern does',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'trigger',
              description: 'Trigger event that activates this pattern',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'actions',
              description: 'JSON array of actions to execute',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final actions = List<String>.from(params['actions']);
    await _automation.createPattern(
      name: params['name'],
      description: params['description'],
      trigger: params['trigger'],
      actions: actions,
    );
    return ToolResult.success('Automation pattern created');
  }
}

class GetPatternsByTriggerTool extends Tool {
  final PredictiveAutomation _automation;

  GetPatternsByTriggerTool(this._automation)
      : super(
          name: 'get_patterns_by_trigger',
          description: 'Get automation patterns that match a specific trigger.',
          parameters: [
            const ToolParameter(
              name: 'trigger',
              description: 'Trigger event to search for',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final patterns = await _automation.getPatternsByTrigger(params['trigger']);
    final data = patterns.map((p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'trigger': p.trigger,
      'actions': p.actions,
      'confidence': p.confidence,
      'useCount': p.useCount,
    }).toList();
    return ToolResult.success(data, metadata: {'count': data.length});
  }
}

class GetAllPatternsTool extends Tool {
  final PredictiveAutomation _automation;

  GetAllPatternsTool(this._automation)
      : super(
          name: 'get_all_patterns',
          description: 'Get all automation patterns.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final patterns = await _automation.getAllPatterns();
    final data = patterns.map((p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'trigger': p.trigger,
      'actions': p.actions,
      'confidence': p.confidence,
      'useCount': p.useCount,
    }).toList();
    return ToolResult.success(data, metadata: {'count': data.length});
  }
}

class RecordAutomationEventTool extends Tool {
  final PredictiveAutomation _automation;

  RecordAutomationEventTool(this._automation)
      : super(
          name: 'record_automation_event',
          description: 'Record an automation event for pattern learning.',
          parameters: [
            const ToolParameter(
              name: 'pattern_id',
              description: 'ID of the pattern to record',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'trigger',
              description: 'Trigger event that occurred',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'executed',
              description: 'Whether the automation was executed',
              type: ToolParameterType.boolean,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _automation.recordEvent(
      patternId: params['pattern_id'],
      trigger: params['trigger'],
      executed: params['executed'] ?? false,
    );
    return ToolResult.success('Event recorded');
  }
}

class UpdatePatternConfidenceTool extends Tool {
  final PredictiveAutomation _automation;

  UpdatePatternConfidenceTool(this._automation)
      : super(
          name: 'update_pattern_confidence',
          description: 'Update the confidence level of an automation pattern.',
          parameters: [
            const ToolParameter(
              name: 'pattern_id',
              description: 'ID of the pattern to update',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'confidence',
              description: 'New confidence level (0-100)',
              type: ToolParameterType.integer,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _automation.updateConfidence(
      params['pattern_id'],
      params['confidence'],
    );
    return ToolResult.success('Confidence updated');
  }
}

class DeletePatternTool extends Tool {
  final PredictiveAutomation _automation;

  DeletePatternTool(this._automation)
      : super(
          name: 'delete_automation_pattern',
          description: 'Delete an automation pattern.',
          parameters: [
            const ToolParameter(
              name: 'pattern_id',
              description: 'ID of the pattern to delete',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _automation.deletePattern(params['pattern_id']);
    return ToolResult.success('Pattern deleted');
  }
}

class GetAutomationStatsTool extends Tool {
  final PredictiveAutomation _automation;

  GetAutomationStatsTool(this._automation)
      : super(
          name: 'get_automation_stats',
          description: 'Get statistics about the automation system.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final stats = await _automation.getStats();
    return ToolResult.success(stats);
  }
}
