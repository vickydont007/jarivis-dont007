import 'dart:async';

enum ToolCategory {
  file,
  system,
  web,
  memory,
  agent,
  automation,
  communication,
  desktop,
  media,
  custom,
}

enum PermissionLevel {
  none,
  read,
  write,
  execute,
  admin,
}

class ToolDefinition {
  final String name;
  final String description;
  final ToolCategory category;
  final PermissionLevel requiredPermission;
  final Map<String, ToolParameter> parameters;
  final bool isEnabled;
  final String? version;
  final String? author;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.category,
    this.requiredPermission = PermissionLevel.read,
    this.parameters = const {},
    this.isEnabled = true,
    this.version,
    this.author,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category.name,
      'requiredPermission': requiredPermission.name,
      'parameters': parameters.map((k, v) => MapEntry(k, v.toMap())),
      'isEnabled': isEnabled,
      'version': version,
      'author': author,
    };
  }
}

class ToolParameter {
  final String name;
  final String description;
  final ToolParameterType type;
  final bool isRequired;
  final dynamic defaultValue;
  final List<dynamic>? allowedValues;

  const ToolParameter({
    required this.name,
    required this.description,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
    this.allowedValues,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.name,
      'isRequired': isRequired,
      'defaultValue': defaultValue,
      'allowedValues': allowedValues,
    };
  }
}

enum ToolParameterType {
  string,
  integer,
  double,
  boolean,
  list,
  map,
  file,
  directory,
}

class ToolResult {
  final bool success;
  final dynamic data;
  final String? error;
  final Map<String, dynamic> metadata;
  final Duration executionTime;

  const ToolResult({
    required this.success,
    this.data,
    this.error,
    this.metadata = const {},
    required this.executionTime,
  });

  factory ToolResult.success(dynamic data, {Map<String, dynamic> metadata = const {}}) {
    return ToolResult(
      success: true,
      data: data,
      metadata: metadata,
      executionTime: Duration.zero,
    );
  }

  factory ToolResult.failure(String error, {Map<String, dynamic> metadata = const {}}) {
    return ToolResult(
      success: false,
      error: error,
      metadata: metadata,
      executionTime: Duration.zero,
    );
  }

  ToolResult withExecutionTime(Duration time) {
    return ToolResult(
      success: success,
      data: data,
      error: error,
      metadata: metadata,
      executionTime: time,
    );
  }
}

typedef ToolHandler = Future<ToolResult> Function(Map<String, dynamic> params);

class RegisteredTool {
  final ToolDefinition definition;
  final ToolHandler handler;
  final DateTime registeredAt;

  const RegisteredTool({
    required this.definition,
    required this.handler,
    required this.registeredAt,
  });
}

class ToolRegistry {
  final Map<String, RegisteredTool> _tools = {};
  final StreamController<ToolDefinition> _registrationController =
      StreamController<ToolDefinition>.broadcast();

  Stream<ToolDefinition> get registrations => _registrationController.stream;

  void register({
    required ToolDefinition definition,
    required ToolHandler handler,
  }) {
    _tools[definition.name] = RegisteredTool(
      definition: definition,
      handler: handler,
      registeredAt: DateTime.now(),
    );
    _registrationController.add(definition);
  }

  void unregister(String name) {
    _tools.remove(name);
  }

  RegisteredTool? getTool(String name) => _tools[name];

  ToolDefinition? getDefinition(String name) => _tools[name]?.definition;

  ToolHandler? getHandler(String name) => _tools[name]?.handler;

  List<ToolDefinition> getAllDefinitions() {
    return _tools.values.map((t) => t.definition).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ToolDefinition> getByCategory(ToolCategory category) {
    return _tools.values
        .where((t) => t.definition.category == category)
        .map((t) => t.definition)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ToolDefinition> getEnabled() {
    return _tools.values
        .where((t) => t.definition.isEnabled)
        .map((t) => t.definition)
        .toList();
  }

  List<ToolDefinition> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _tools.values.where((t) {
      return t.definition.name.toLowerCase().contains(lowerQuery) ||
          t.definition.description.toLowerCase().contains(lowerQuery);
    }).map((t) => t.definition).toList();
  }

  bool hasTool(String name) => _tools.containsKey(name);

  int get count => _tools.length;

  Map<String, dynamic> getStats() {
    final categories = <ToolCategory, int>{};
    for (final tool in _tools.values) {
      categories[tool.definition.category] =
          (categories[tool.definition.category] ?? 0) + 1;
    }
    return {
      'total': _tools.length,
      'enabled': _tools.values.where((t) => t.definition.isEnabled).length,
      'categories': categories.map((k, v) => MapEntry(k.name, v)),
    };
  }

  void dispose() {
    _registrationController.close();
  }
}
