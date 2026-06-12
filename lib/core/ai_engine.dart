import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/tool.dart';

enum AIProvider {
  openrouter,
  ollama,
  openai,
  anthropic,
  gemini,
}

enum AIEngineState {
  disconnected,
  connected,
  connecting,
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] ?? '',
      name: json['function']?['name'] ?? '',
      arguments: json['function']?['arguments'] is String
          ? jsonDecode(json['function']?['arguments'] ?? '{}')
          : json['function']?['arguments'] ?? {},
    );
  }
}

class AIEngine {
  final AIProvider _provider;
  final String _apiKey;
  final String _baseUrl;
  final String _modelName;
  String _systemPrompt = '';
  List<Map<String, dynamic>> _toolDefinitions = [];
  AIEngineState state = AIEngineState.disconnected;
  final Dio _dio = Dio();
  final StreamController<String> _responseController = StreamController<String>.broadcast();

  AIEngine({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
    String? modelName,
    String? systemPrompt,
    List<Map<String, dynamic>>? toolDefinitions,
  }) : _provider = provider,
       _apiKey = apiKey,
       _baseUrl = baseUrl ?? _getDefaultBaseUrl(provider),
       _modelName = modelName ?? _getDefaultModel(provider),
       _systemPrompt = systemPrompt ?? '',
       _toolDefinitions = toolDefinitions ?? [];

  static String _getDefaultBaseUrl(AIProvider provider) {
    switch (provider) {
      case AIProvider.openrouter:
        return 'https://openrouter.ai/api/v1';
      case AIProvider.ollama:
        return 'http://localhost:11434/v1';
      case AIProvider.openai:
        return 'https://api.openai.com/v1';
      case AIProvider.anthropic:
        return 'https://api.anthropic.com/v1';
      case AIProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1';
    }
  }

  Stream<String> get responseStream => _responseController.stream;

  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  void setToolDefinitions(List<Map<String, dynamic>> tools) {
    _toolDefinitions = tools;
  }

  void addToolDefinition(Map<String, dynamic> tool) {
    _toolDefinitions.add(tool);
  }

  void clearToolDefinitions() {
    _toolDefinitions.clear();
  }

  List<Map<String, dynamic>> get toolDefinitions => _toolDefinitions;

  Future<void> connect() async {
    state = AIEngineState.connected;
  }

  Future<void> disconnect() async {
    state = AIEngineState.disconnected;
  }

  static bool isImageRequest(String message) {
    final lower = message.toLowerCase();
    return lower.contains('generate image') ||
        lower.contains('make image') ||
        lower.contains('create image') ||
        lower.contains('draw') ||
        lower.contains('generate picture') ||
        lower.contains('make a picture') ||
        lower.contains('create a picture') ||
        lower.startsWith('imagine') ||
        lower.startsWith('generate');
  }

  List<Map<String, dynamic>> _buildMessages(
    String message,
    List<Map<String, dynamic>>? history,
  ) {
    final messages = <Map<String, dynamic>>[];

    if (_systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': _systemPrompt});
    }

    if (history != null) {
      messages.addAll(history);
    }

    messages.add({'role': 'user', 'content': message});
    return messages;
  }

  Map<String, dynamic> _buildRequestBody(
    List<Map<String, dynamic>> messages, {
    bool stream = false,
  }) {
    final body = <String, dynamic>{
      'model': _getModelName(),
      'messages': messages,
      'stream': stream,
    };

    if (_toolDefinitions.isNotEmpty) {
      body['tools'] = _toolDefinitions;
      body['tool_choice'] = 'auto';
    }

    return body;
  }

  Options _buildOptions({ResponseType? responseType}) {
    return Options(
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
            'HTTP-Referer': 'https://nextron-ai.app',
            'X-Title': 'Nextron AI',
      },
      responseType: responseType,
      validateStatus: (status) => status! < 500,
    );
  }

  Future<String> sendMessage(String message, {List<Map<String, dynamic>>? history}) async {
    try {
      final messages = _buildMessages(message, history);
      final body = _buildRequestBody(messages);

      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: _buildOptions(),
        data: body,
      );

      return _handleResponse(response);
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<Map<String, dynamic>> sendMessageWithTools(
    String message, {
    List<Map<String, dynamic>>? history,
    required Future<ToolResult> Function(String name, Map<String, dynamic> args) onToolCall,
    int maxIterations = 5,
  }) async {
    final messages = _buildMessages(message, history);
    final allToolCalls = <ToolCall>[];
    final allToolResults = <Map<String, dynamic>>[];

    for (var i = 0; i < maxIterations; i++) {
      final body = _buildRequestBody(messages);

      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: _buildOptions(),
        data: body,
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'API error: ${response.statusCode}',
          'toolCalls': allToolCalls,
          'toolResults': allToolResults,
        };
      }

      final data = response.data;
      final choice = data['choices']?[0];
      final message = choice?['message'];

      if (message == null) {
        return {
          'success': false,
          'error': 'No response from AI',
          'toolCalls': allToolCalls,
          'toolResults': allToolResults,
        };
      }

      final toolCallsRaw = message['tool_calls'] as List?;
      if (toolCallsRaw != null && toolCallsRaw.isNotEmpty) {
        messages.add(message);

        for (final tc in toolCallsRaw) {
          final toolCall = ToolCall.fromJson(tc);
          allToolCalls.add(toolCall);

          final result = await onToolCall(toolCall.name, toolCall.arguments);
          allToolResults.add({
            'tool_call_id': toolCall.id,
            'name': toolCall.name,
            'result': result.toDisplayString(),
            'success': result.success,
          });

          messages.add({
            'role': 'tool',
            'tool_call_id': toolCall.id,
            'content': result.toDisplayString(),
          });
        }
      } else {
        final content = message['content'] ?? '';
        return {
          'success': true,
          'content': content,
          'toolCalls': allToolCalls,
          'toolResults': allToolResults,
          'iterations': i + 1,
        };
      }
    }

    return {
      'success': false,
      'error': 'Max tool call iterations reached',
      'toolCalls': allToolCalls,
      'toolResults': allToolResults,
    };
  }

  String _handleResponse(Response response) {
    if (response.statusCode == 200) {
      final data = response.data;
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        final message = data['choices'][0]['message'];
        final toolCalls = message['tool_calls'] as List?;

        if (toolCalls != null && toolCalls.isNotEmpty) {
          final toolNames = toolCalls.map((tc) {
            final name = tc['function']?['name'] ?? 'unknown';
            return '[$name]';
          }).join(', ');
          final textContent = message['content'] ?? '';
          return '$textContent\n\nTools called: $toolNames';
        }

        return message['content'] ?? '';
      }
      return 'Error: No response from AI';
    } else if (response.statusCode == 404) {
      return 'Error: Model not found (${_getModelName()}). Try another model.';
    } else if (response.statusCode == 401) {
      return 'Error: Invalid API key. Please check your OpenRouter API key.';
    } else if (response.statusCode == 402) {
      return 'Error: Insufficient credits.';
    } else {
      final error = response.data['error']?['message'] ?? 'Unknown error';
      return 'Error ($response.statusCode): $error';
    }
  }

  Stream<String> sendMessageStream(String message, {List<Map<String, dynamic>>? history}) async* {
    try {
      final messages = _buildMessages(message, history);
      final body = _buildRequestBody(messages, stream: true);

      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: _buildOptions(responseType: ResponseType.stream),
        data: body,
      );

      if (response.statusCode == 200) {
        await for (final chunk in (response.data as Stream).transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data == '[DONE]') break;

              try {
                final json = jsonDecode(data);
                if (json['choices'] != null && json['choices'].isNotEmpty) {
                  final content = json['choices'][0]['delta']?['content'] ?? '';
                  if (content.isNotEmpty) {
                    yield content;
                  }
                }
              } catch (e) {
                // Skip invalid JSON
              }
            }
          }
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  Future<Map<String, dynamic>> generateImage(String prompt) async {
    try {
      final imageModel = _getImageModel();
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: _buildOptions(),
        data: {
          'model': imageModel,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']['content'] ?? '';
          final imageUrls = _extractImageUrls(content);
          return {
            'success': true,
            'content': content,
            'imageUrls': imageUrls,
            'model': imageModel,
          };
        }
        return {
          'success': false,
          'error': 'No response from AI',
          'model': imageModel,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Invalid API key',
          'model': imageModel,
        };
      } else if (response.statusCode == 402) {
        return {
          'success': false,
          'error': 'Insufficient credits. Try a free model.',
          'model': imageModel,
        };
      } else {
        final error = response.data['error']?['message'] ?? 'Unknown error';
        return {
          'success': false,
          'error': '$error (${response.statusCode})',
          'model': imageModel,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'model': 'unknown',
      };
    }
  }

  List<String> _extractImageUrls(String content) {
    final urls = <String>[];
    final markdownRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    for (final match in markdownRegex.allMatches(content)) {
      urls.add(match.group(1)!);
    }
    final urlRegex = RegExp(r'https?://[^\s\)]+\.(png|jpg|jpeg|gif|webp)');
    for (final match in urlRegex.allMatches(content)) {
      final url = match.group(0)!;
      if (!urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  String _getModelName() {
    return _modelName;
  }

  String _getImageModel() {
    if (_modelName.contains('flux') || _modelName.contains('dall-e') || _modelName.contains('stable-diffusion')) {
      return _modelName;
    }
    return 'black-forest-labs/flux-schnell:free';
  }

  static String _getDefaultModel(AIProvider provider) {
    switch (provider) {
      case AIProvider.openrouter:
        return 'google/gemma-4-26b-a4b-it:free';
      case AIProvider.ollama:
        return 'llama3.2';
      case AIProvider.openai:
        return 'gpt-4';
      case AIProvider.anthropic:
        return 'claude-3-opus';
      case AIProvider.gemini:
        return 'gemini-2.0-flash';
    }
  }

  void dispose() {
    disconnect();
    _responseController.close();
  }
}

class AIEngineProvider {
  static AIEngine create({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
    String? systemPrompt,
    List<Map<String, dynamic>>? toolDefinitions,
  }) {
    return AIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      systemPrompt: systemPrompt,
      toolDefinitions: toolDefinitions,
    );
  }
}
