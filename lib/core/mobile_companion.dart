import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MobileRequest {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final Map<String, String> headers;
  final DateTime timestamp;

  MobileRequest({
    required this.id,
    required this.method,
    required this.path,
    this.body = const {},
    this.headers = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'path': path,
    'body': body,
    'headers': headers,
    'timestamp': timestamp.toIso8601String(),
  };
}

class MobileResponse {
  final String requestId;
  final int statusCode;
  final dynamic data;
  final String? error;

  MobileResponse({
    required this.requestId,
    required this.statusCode,
    this.data,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'status_code': statusCode,
    'data': data,
    'error': error,
  };
}

class MobileCompanion {
  HttpServer? _server;
  int _port = 8080;
  final StreamController<MobileRequest> _requestController =
      StreamController<MobileRequest>.broadcast();
  final Map<String, Future<MobileResponse> Function(MobileRequest)> _handlers = {};

  Stream<MobileRequest> get requestStream => _requestController.stream;
  int get port => _port;
  bool get isRunning => _server != null;

  void registerHandler(String path, Future<MobileResponse> Function(MobileRequest) handler) {
    _handlers[path] = handler;
  }

  Future<void> start({int port = 8080}) async {
    _port = port;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);

    _server!.listen((HttpRequest request) async {
      try {
        final body = await _collectRequestBody(request);
        final mobileRequest = MobileRequest(
          id: 'req_${DateTime.now().millisecondsSinceEpoch}',
          method: request.method,
          path: request.uri.path,
          body: body,
          headers: {},
          timestamp: DateTime.now(),
        );

        _requestController.add(mobileRequest);

        final handler = _handlers[request.uri.path];
        if (handler != null) {
          final response = await handler(mobileRequest);
          await _sendResponse(request.response, response);
        } else {
          await _sendResponse(
            request.response,
            MobileResponse(
              requestId: mobileRequest.id,
              statusCode: 404,
              error: 'Not found',
            ),
          );
        }
      } catch (e) {
        await _sendResponse(
          request.response,
          MobileResponse(
            requestId: '',
            statusCode: 500,
            error: e.toString(),
          ),
        );
      }
    });
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  Future<Map<String, dynamic>> _collectRequestBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.isEmpty) return {};

    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {'raw': content};
    }
  }

  Future<void> _sendResponse(HttpResponse response, MobileResponse mobileResponse) async {
    response.headers.contentType = ContentType.json;
    response.statusCode = mobileResponse.statusCode;
    response.write(jsonEncode(mobileResponse.toJson()));
    await response.close();
  }

  void registerDefaultHandlers({
    required Future<String> Function(String message) onChat,
    required Future<Map<String, dynamic>> Function() onStatus,
    required Future<List<Map<String, dynamic>>> Function() onAgents,
    required Future<void> Function(String agentId) onAgentSpawn,
    required Future<void> Function(String agentId) onAgentKill,
  }) {
    registerHandler('/api/chat', (request) async {
      final message = request.body['message'] as String? ?? '';
      final response = await onChat(message);
      return MobileResponse(
        requestId: request.id,
        statusCode: 200,
        data: {'response': response},
      );
    });

    registerHandler('/api/status', (request) async {
      final status = await onStatus();
      return MobileResponse(
        requestId: request.id,
        statusCode: 200,
        data: status,
      );
    });

    registerHandler('/api/agents', (request) async {
      final agents = await onAgents();
      return MobileResponse(
        requestId: request.id,
        statusCode: 200,
        data: agents,
      );
    });

    registerHandler('/api/agents/spawn', (request) async {
      final agentId = request.body['agent_id'] as String? ?? '';
      await onAgentSpawn(agentId);
      return MobileResponse(
        requestId: request.id,
        statusCode: 200,
        data: {'success': true},
      );
    });

    registerHandler('/api/agents/kill', (request) async {
      final agentId = request.body['agent_id'] as String? ?? '';
      await onAgentKill(agentId);
      return MobileResponse(
        requestId: request.id,
        statusCode: 200,
        data: {'success': true},
      );
    });
  }

  Map<String, dynamic> getServerInfo() => {
    'port': _port,
    'running': isRunning,
    'handlers': _handlers.keys.toList(),
  };

  void dispose() {
    stop();
    _requestController.close();
  }
}
