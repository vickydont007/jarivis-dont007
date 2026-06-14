import 'dart:async';

enum AutomationTrigger {
  time,
  event,
  condition,
  manual,
}

enum AutomationAction {
  runTool,
  sendNotification,
  updateMemory,
  startAgent,
  stopAgent,
  runWorkflow,
}

class ParsedAutomation {
  final String? name;
  final AutomationTrigger trigger;
  final Map<String, dynamic> triggerConfig;
  final List<ParsedAction> actions;
  final String originalText;
  final double confidence;
  final List<String> suggestions;

  const ParsedAutomation({
    this.name,
    required this.trigger,
    required this.triggerConfig,
    required this.actions,
    required this.originalText,
    this.confidence = 1.0,
    this.suggestions = const [],
  });
}

class ParsedAction {
  final AutomationAction type;
  final String? toolName;
  final Map<String, dynamic> params;
  final String description;

  const ParsedAction({
    required this.type,
    this.toolName,
    this.params = const {},
    required this.description,
  });
}

class AutomationParseResult {
  final bool success;
  final ParsedAutomation? automation;
  final String? error;
  final List<String> alternatives;

  const AutomationParseResult({
    required this.success,
    this.automation,
    this.error,
    this.alternatives = const [],
  });
}

class NaturalLanguageParser {
  final Map<String, List<String>> _timePatterns = {
    'every_hour': ['every hour', 'hourly', 'each hour'],
    'every_2_hours': ['every 2 hours', 'every two hours', 'bi-hourly'],
    'every_30_min': ['every 30 minutes', 'every half hour', 'half-hourly'],
    'daily_morning': ['every morning', 'daily at morning', 'each morning'],
    'daily_evening': ['every evening', 'daily at evening'],
    'daily_9am': ['every day at 9', 'daily at 9am', 'each day at 9'],
    'weekly': ['every week', 'weekly', 'each week'],
    'monthly': ['every month', 'monthly', 'each month'],
  };

  final Map<String, List<String>> _actionPatterns = {
    'check_email': ['check email', 'check emails', 'read email', 'read emails'],
    'send_report': ['send report', 'email report', 'report to'],
    'backup': ['backup', 'back up', 'create backup'],
    'scan_web': ['scan web', 'check website', 'monitor website', 'watch website'],
    'remind': ['remind me', 'set reminder', 'create reminder'],
    'schedule': ['schedule', 'create meeting', 'set meeting', 'add to calendar'],
    'run_analysis': ['run analysis', 'analyze', 'perform analysis'],
    'generate_report': ['generate report', 'create report', 'make report'],
  };

  AutomationParseResult parse(String input) {
    final lowerInput = input.toLowerCase().trim();

    // Detect trigger
    final trigger = _detectTrigger(lowerInput);
    if (trigger == null) {
      return AutomationParseResult(
        success: false,
        error: 'Could not understand the trigger. Try "every day", "every hour", etc.',
        alternatives: [
          'Try: "Every day at 9am, check my emails"',
          'Try: "Every hour, scan the web"',
          'Try: "Weekly, generate a report"',
        ],
      );
    }

    // Detect actions
    final actions = _detectActions(lowerInput);
    if (actions.isEmpty) {
      return AutomationParseResult(
        success: false,
        error: 'Could not understand what action to perform.',
        alternatives: [
          'Try: "check emails"',
          'Try: "send a report"',
          'Try: "backup files"',
        ],
      );
    }

    // Generate name
    final name = _generateName(trigger, actions, lowerInput);

    return AutomationParseResult(
      success: true,
      automation: ParsedAutomation(
        name: name,
        trigger: trigger.trigger,
        triggerConfig: trigger.config,
        actions: actions,
        originalText: input,
        confidence: 0.9,
      ),
    );
  }

  _TriggerResult? _detectTrigger(String input) {
    // Time-based triggers
    for (final entry in _timePatterns.entries) {
      for (final pattern in entry.value) {
        if (input.contains(pattern)) {
          return _TriggerResult(
            trigger: AutomationTrigger.time,
            config: _parseTimeConfig(entry.key),
          );
        }
      }
    }

    // Event-based triggers
    if (input.contains('when') || input.contains('on')) {
      return _TriggerResult(
        trigger: AutomationTrigger.event,
        config: {'event': _extractEvent(input)},
      );
    }

    return null;
  }

  Map<String, dynamic> _parseTimeConfig(String type) {
    switch (type) {
      case 'every_hour':
        return {'interval': 'hourly'};
      case 'every_2_hours':
        return {'interval': '2h'};
      case 'every_30_min':
        return {'interval': '30m'};
      case 'daily_morning':
        return {'schedule': 'daily:09-00'};
      case 'daily_evening':
        return {'schedule': 'daily:18-00'};
      case 'daily_9am':
        return {'schedule': 'daily:09-00'};
      case 'weekly':
        return {'schedule': 'weekly'};
      case 'monthly':
        return {'schedule': 'monthly'};
      default:
        return {'interval': 'daily'};
    }
  }

  String _extractEvent(String input) {
    if (input.contains('receive') || input.contains('got email')) {
      return 'email_received';
    }
    if (input.contains('file') || input.contains('download')) {
      return 'file_created';
    }
    if (input.contains('mention') || input.contains('notification')) {
      return 'notification';
    }
    return 'custom';
  }

  List<ParsedAction> _detectActions(String input) {
    final actions = <ParsedAction>[];

    for (final entry in _actionPatterns.entries) {
      for (final pattern in entry.value) {
        if (input.contains(pattern)) {
          actions.add(_createAction(entry.key, input));
          break;
        }
      }
    }

    // Default to generic tool execution if no specific action matched
    if (actions.isEmpty && input.isNotEmpty) {
      actions.add(ParsedAction(
        type: AutomationAction.runTool,
        toolName: 'web_search',
        params: {'query': input},
        description: 'Execute: $input',
      ));
    }

    return actions;
  }

  ParsedAction _createAction(String actionType, String input) {
    switch (actionType) {
      case 'check_email':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'email_list',
          params: {'filter': 'unread'},
          description: 'Check for unread emails',
        );
      case 'send_report':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'email_send',
          params: {'type': 'report'},
          description: 'Send daily report',
        );
      case 'backup':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'file_backup',
          params: {'scope': 'documents'},
          description: 'Backup important files',
        );
      case 'scan_web':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'web_fetch',
          params: {},
          description: 'Scan web for updates',
        );
      case 'remind':
        return const ParsedAction(
          type: AutomationAction.sendNotification,
          params: {'type': 'reminder'},
          description: 'Send reminder notification',
        );
      case 'schedule':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'calendar_create',
          params: {},
          description: 'Create calendar event',
        );
      case 'run_analysis':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'data_analyze',
          params: {},
          description: 'Run data analysis',
        );
      case 'generate_report':
        return const ParsedAction(
          type: AutomationAction.runTool,
          toolName: 'report_generate',
          params: {},
          description: 'Generate activity report',
        );
      default:
        return ParsedAction(
          type: AutomationAction.runTool,
          params: {'input': input},
          description: 'Execute action',
        );
    }
  }

  String _generateName(
    _TriggerResult trigger,
    List<ParsedAction> actions,
    String input,
  ) {
    final actionDesc = actions.first.description;
    final triggerDesc = trigger.config['schedule'] ?? trigger.config['interval'] ?? 'custom';
    return '$actionDesc ($triggerDesc)';
  }

  List<String> getSuggestions(String partial) {
    final suggestions = <String>[];
    final lower = partial.toLowerCase();

    if (lower.isEmpty) {
      return [
        'Every day at 9am, check my emails',
        'Every hour, scan the web for updates',
        'Weekly, generate a summary report',
        'Daily, backup important files',
      ];
    }

    for (final entry in _actionPatterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.contains(lower) || lower.contains(pattern)) {
          suggestions.add('Try: "$pattern"');
        }
      }
    }

    return suggestions.take(5).toList();
  }
}

class _TriggerResult {
  final AutomationTrigger trigger;
  final Map<String, dynamic> config;

  const _TriggerResult({
    required this.trigger,
    required this.config,
  });
}
