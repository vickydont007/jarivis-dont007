import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';

enum AIProvider {
  openrouter,
  ollama,
  openai,
  anthropic,
  gemini,
}

class AIEngine {
  final AIProvider _provider;
  final String _apiKey;
  final String _baseUrl;
  WebSocketChannel? _channel;
  final Dio _dio = Dio();
  final StreamController<String> _responseController = StreamController<String>.broadcast();

  AIEngine({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
  }) : _provider = provider,
       _apiKey = apiKey,
       _baseUrl = baseUrl ?? _getDefaultBaseUrl(provider);

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

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(_baseUrl),
      );

      _channel!.stream.listen(
        (data) {
          final message = jsonDecode(data.toString());
          if (message['choices'] != null &&
              message['choices'].isNotEmpty) {
            final content = message['choices'][0]['delta']?['content'] ?? '';
            if (content.isNotEmpty) {
              _responseController.add(content);
            }
          }
        },
        onError: (error) {
          _responseController.addError(error);
        },
        onDone: () {
          _responseController.close();
        },
      );
    } catch (e) {
      _responseController.addError(e);
    }
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  Future<String> sendMessage(String message, {List<Map<String, dynamic>>? history}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': _getModelName(),
          'messages': [
            if (history != null) ...history,
            {'role': 'user', 'content': message},
          ],
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ?? '';
        }
      }
      return 'Error: Unexpected response';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Stream<String> sendMessageStream(String message, {List<Map<String, dynamic>>? history}) async* {
    try {
      final request = {
        'model': _getModelName(),
        'messages': [
          if (history != null) ...history,
          {'role': 'user', 'content': message},
        ],
        'stream': true,
      };

      _channel!.sink.add(jsonEncode(request));

      await for (final data in _channel!.stream) {
        final message = jsonDecode(data.toString());
        if (message['choices'] != null && message['choices'].isNotEmpty) {
          final content = message['choices'][0]['delta']?['content'] ?? '';
          if (content.isNotEmpty) {
            yield content;
          }
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  String _getModelName() {
    switch (_provider) {
      case AIProvider.openrouter:
        return 'anthropic/claude-3.5-sonnet';
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

// Provider for AI Engine
class AIEngineProvider {
  static AIEngine create({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
  }) {
    return AIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
  }
}
