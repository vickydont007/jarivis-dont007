import 'dart:async';

class VoiceCommand {
  final String id;
  final String pattern;
  final String action;
  final Map<String, dynamic> params;
  final String description;

  VoiceCommand({
    required this.id,
    required this.pattern,
    required this.action,
    this.params = const {},
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'pattern': pattern,
    'action': action,
    'params': params,
    'description': description,
  };

  factory VoiceCommand.fromJson(Map<String, dynamic> json) {
    return VoiceCommand(
      id: json['id'],
      pattern: json['pattern'],
      action: json['action'],
      params: json['params'] ?? {},
      description: json['description'],
    );
  }
}

class VoiceCommandResult {
  final VoiceCommand command;
  final Map<String, dynamic> extractedParams;
  final double confidence;

  VoiceCommandResult({
    required this.command,
    required this.extractedParams,
    required this.confidence,
  });
}

class VoiceCommandSystem {
  final List<VoiceCommand> _commands = [];
  final StreamController<VoiceCommand> _commandController =
      StreamController<VoiceCommand>.broadcast();

  Stream<VoiceCommand> get commandStream => _commandController.stream;

  void registerCommand(VoiceCommand command) {
    _commands.add(command);
  }

  void registerCommands(List<VoiceCommand> commands) {
    _commands.addAll(commands);
  }

  void unregisterCommand(String commandId) {
    _commands.removeWhere((c) => c.id == commandId);
  }

  VoiceCommandResult? matchCommand(String input) {
    final lower = input.toLowerCase().trim();

    for (final command in _commands) {
      final pattern = command.pattern.toLowerCase();
      final confidence = _calculateMatchConfidence(lower, pattern);

      if (confidence > 0.6) {
        final extractedParams = _extractParams(lower, pattern, command.params);
        return VoiceCommandResult(
          command: command,
          extractedParams: extractedParams,
          confidence: confidence,
        );
      }
    }

    return null;
  }

  double _calculateMatchConfidence(String input, String pattern) {
    if (input == pattern) return 1.0;

    final inputWords = input.split(' ');
    final patternWords = pattern.split(' ');

    var matches = 0;
    for (final patternWord in patternWords) {
      for (final inputWord in inputWords) {
        if (inputWord.contains(patternWord) || patternWord.contains(inputWord)) {
          matches++;
          break;
        }
      }
    }

    return matches / patternWords.length;
  }

  Map<String, dynamic> _extractParams(String input, String pattern, Map<String, dynamic> defaultParams) {
    final params = Map<String, dynamic>.from(defaultParams);

    final paramPattern = RegExp(r'\{(\w+)\}');
    for (final match in paramPattern.allMatches(pattern)) {
      final paramName = match.group(1);
      if (paramName != null) {
        final inputParts = input.split(' ');
        final patternParts = pattern.split(' ');
        final paramIndex = patternParts.indexOf('{$paramName}');

        if (paramIndex >= 0 && paramIndex < inputParts.length) {
          params[paramName] = inputParts[paramIndex];
        }
      }
    }

    return params;
  }

  List<VoiceCommand> getAllCommands() => List.unmodifiable(_commands);

  List<VoiceCommand> searchCommands(String query) {
    final lower = query.toLowerCase();
    return _commands.where((c) {
      return c.pattern.toLowerCase().contains(lower) ||
          c.description.toLowerCase().contains(lower) ||
          c.action.toLowerCase().contains(lower);
    }).toList();
  }

  void clear() {
    _commands.clear();
  }

  void dispose() {
    _commandController.close();
  }
}

List<VoiceCommand> getDefaultVoiceCommands() {
  return [
    VoiceCommand(
      id: 'shutdown',
      pattern: 'shutdown computer',
      action: 'system_shutdown',
      description: 'Shut down the computer',
    ),
    VoiceCommand(
      id: 'restart',
      pattern: 'restart computer',
      action: 'system_restart',
      description: 'Restart the computer',
    ),
    VoiceCommand(
      id: 'sleep',
      pattern: 'sleep computer',
      action: 'system_sleep',
      description: 'Put computer to sleep',
    ),
    VoiceCommand(
      id: 'lock',
      pattern: 'lock screen',
      action: 'system_lock',
      description: 'Lock the workstation',
    ),
    VoiceCommand(
      id: 'weather',
      pattern: 'weather in {city}',
      action: 'weather_current',
      params: {'city': 'auto'},
      description: 'Get weather for a city',
    ),
    VoiceCommand(
      id: 'search_files',
      pattern: 'find file {name}',
      action: 'file_search',
      params: {'path': '~'},
      description: 'Search for a file',
    ),
    VoiceCommand(
      id: 'list_files',
      pattern: 'list files in {path}',
      action: 'file_list',
      description: 'List files in a directory',
    ),
    VoiceCommand(
      id: 'run_code',
      pattern: 'run {code}',
      action: 'code_execute',
      params: {'language': 'python'},
      description: 'Execute code',
    ),
    VoiceCommand(
      id: 'open_app',
      pattern: 'open {app_name}',
      action: 'system_open_app',
      description: 'Open an application',
    ),
    VoiceCommand(
      id: 'open_url',
      pattern: 'open website {url}',
      action: 'web_open_url',
      description: 'Open a website',
    ),
    VoiceCommand(
      id: 'search_memory',
      pattern: 'remember {query}',
      action: 'memory_search',
      description: 'Search memories',
    ),
    VoiceCommand(
      id: 'add_memory',
      pattern: 'save memory {content}',
      action: 'memory_add',
      description: 'Add a new memory',
    ),
  ];
}
