import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class DiscordMessage {
  final String id;
  final String channelId;
  final String? guildId;
  final String content;
  final String? authorUsername;
  final DateTime timestamp;

  DiscordMessage({
    required this.id,
    required this.channelId,
    this.guildId,
    required this.content,
    this.authorUsername,
    required this.timestamp,
  });

  factory DiscordMessage.fromJson(Map<String, dynamic> json) {
    return DiscordMessage(
      id: json['id'],
      channelId: json['channel_id'],
      guildId: json['guild_id'],
      content: json['content'] ?? '',
      authorUsername: json['author']?['username'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class DiscordService {
  final Dio _dio = Dio();
  String? _botToken;
  String? _botUserId;
  WebSocketChannel? _channel;
  int? _lastSequence;
  String? _sessionId;
  Timer? _heartbeatTimer;
  final StreamController<DiscordMessage> _messageController =
      StreamController<DiscordMessage>.broadcast();

  Stream<DiscordMessage> get messageStream => _messageController.stream;

  void setBotToken(String token) {
    _botToken = token;
  }

  String get botToken => _botToken ?? '';

  // Initialize bot
  Future<bool> initialize() async {
    if (_botToken == null || _botToken!.isEmpty) {
      throw Exception('Bot token not set');
    }

    try {
      final response = await _dio.get(
        'https://discord.com/api/v10/users/@me',
        options: Options(
          headers: {
            'Authorization': 'Bot $_botToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        _botUserId = response.data['id'];
        return true;
      }
      return false;
    } catch (e) {
      print('Error initializing Discord bot: $e');
      return false;
    }
  }

  // Connect to WebSocket
  Future<void> connect() async {
    if (_botToken == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://gateway.discord.gg/?v=10&encoding=json'),
      );

      _channel!.stream.listen(
        (data) {
          final message = jsonDecode(data.toString());
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _reconnect();
        },
        onDone: () {
          print('WebSocket closed');
          _reconnect();
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    if (message['op'] != null) {
      _handleOpcode(message['op'], message['d']);
    }

    if (message['s'] != null) {
      _lastSequence = message['s'];
    }

    if (message['t'] == 'MESSAGE_CREATE') {
      final eventData = message['d'];
      if (eventData['author']?['id'] != _botUserId) {
        final discordMessage = DiscordMessage.fromJson(eventData);
        _messageController.add(discordMessage);
      }
    }
  }

  void _handleOpcode(int opcode, dynamic data) {
    switch (opcode) {
      case 0: // Dispatch
        if (data != null && data['session_id'] != null) {
          _sessionId = data['session_id'];
        }
        break;
      case 10: // Hello
        final heartbeatInterval = data['heartbeat_interval'];
        _startHeartbeat(heartbeatInterval);
        _identify();
        break;
      case 11: // Heartbeat ACK
        print('Heartbeat acknowledged');
        break;
    }
  }

  void _startHeartbeat(int interval) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: interval),
      (timer) {
        _sendHeartbeat();
      },
    );
  }

  void _sendHeartbeat() {
    _sendPayload({
      'op': 1,
      'd': _lastSequence,
    });
  }

  void _identify() {
    _sendPayload({
      'op': 2,
      'd': {
        'token': _botToken,
        'intents': 513, // GUILDS + GUILD_MESSAGES
      },
    });
  }

  void _sendPayload(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void _reconnect() {
    Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  // Send message to channel
  Future<bool> sendMessage(String channelId, String content) async {
    if (_botToken == null) return false;

    try {
      final response = await _dio.post(
        'https://discord.com/api/v10/channels/$channelId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bot $_botToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'content': content,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Send embed
  Future<bool> sendEmbed(
    String channelId, {
    required String title,
    required String description,
    int? color,
  }) async {
    if (_botToken == null) return false;

    try {
      final response = await _dio.post(
        'https://discord.com/api/v10/channels/$channelId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bot $_botToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'embeds': [
            {
              'title': title,
              'description': description,
              if (color != null) 'color': color,
            }
          ],
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending embed: $e');
      return false;
    }
  }

  // Get channel info
  Future<Map<String, dynamic>?> getChannel(String channelId) async {
    if (_botToken == null) return null;

    try {
      final response = await _dio.get(
        'https://discord.com/api/v10/channels/$channelId',
        options: Options(
          headers: {
            'Authorization': 'Bot $_botToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error getting channel: $e');
      return null;
    }
  }

  // Get guild channels
  Future<List<Map<String, dynamic>>> getGuildChannels(String guildId) async {
    if (_botToken == null) return [];

    try {
      final response = await _dio.get(
        'https://discord.com/api/v10/guilds/$guildId/channels',
        options: Options(
          headers: {
            'Authorization': 'Bot $_botToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('Error getting guild channels: $e');
      return [];
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
  }
}
