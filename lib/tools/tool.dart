import 'dart:async';

enum ToolParameterType {
  string,
  integer,
  number,
  boolean,
  array,
  object,
}

class ToolParameter {
  final String name;
  final String description;
  final ToolParameterType type;
  final bool required;
  final dynamic defaultValue;
  final List<String>? enumValues;

  const ToolParameter({
    required this.name,
    required this.description,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.enumValues,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type.name,
      'description': description,
    };
    if (enumValues != null) {
      json['enum'] = enumValues;
    }
    if (defaultValue != null) {
      json['default'] = defaultValue;
    }
    return json;
  }
}

class ToolResult {
  final bool success;
  final dynamic data;
  final String? error;
  final Map<String, dynamic>? metadata;

  const ToolResult({
    required this.success,
    this.data,
    this.error,
    this.metadata,
  });

  factory ToolResult.success(dynamic data, {Map<String, dynamic>? metadata}) {
    return ToolResult(success: true, data: data, metadata: metadata);
  }

  factory ToolResult.error(String error) {
    return ToolResult(success: false, error: error);
  }

  String toDisplayString() {
    if (!success) return 'Error: $error';
    if (data == null) return 'Done';
    if (data is String) return data;
    return data.toString();
  }
}

abstract class Tool {
  final String name;
  final String description;
  final List<ToolParameter> parameters;

  const Tool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  FutureOr<ToolResult> execute(Map<String, dynamic> params);

  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': {
            for (final param in parameters) param.name: param.toJson(),
          },
          'required': parameters.where((p) => p.required).map((p) => p.name).toList(),
        },
      },
    };
  }
}
