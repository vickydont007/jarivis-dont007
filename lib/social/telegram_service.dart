import 'dart:async';
import 'package:dio/dio.dart';

class TelegramMessage {
  final int messageId;
  final int chatId;
  final String text;
  final String? fromUsername;
  final DateTime timestamp;

  TelegramMessage({
    required this.messageId,
    required this.chatId,
    required this.text,
    this.fromUsername,
    required this.timestamp,
  });

  factory TelegramMessage.fromJson(Map<String, dynamic> json) {
    return TelegramMessage(
      messageId: json['message_id'],
      chatId: json['chat']['id'],
      text: json['text'] ?? '',
      fromUsername: json['from']?['username'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['date'] * 1000),
    );
  }
}

class TelegramService {
  final Dio _dio = Dio();
  String? _botToken;
  String? _botUsername;
  int? _lastUpdateId;
  Timer? _pollingTimer;
  final StreamController<TelegramMessage> _messageController =
      StreamController<TelegramMessage>.broadcast();

  Stream<TelegramMessage> get messageStream => _messageController.stream;

  void setBotToken(String token) {
    _botToken = token;
  }

  String get botToken => _botToken ?? '';
  String get botUsername => _botUsername ?? '';

  // Initialize bot
  Future<bool> initialize() async {
    if (_botToken == null || _botToken!.isEmpty) {
      throw Exception('Bot token not set');
    }

    try {
      final response = await _dio.get(
        'https://api.telegram.org/bot$_botToken/getMe',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ok']) {
          _botUsername = data['result']['username'];
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error initializing Telegram bot: $e');
      return false;
    }
  }

  // Start polling for messages
  void startPolling({Duration interval = const Duration(seconds: 1)}) {
    _pollingTimer = Timer.periodic(interval, (timer) async {
      await _getUpdates();
    });
  }

  // Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // Get updates from Telegram
  Future<void> _getUpdates() async {
    if (_botToken == null) return;

    try {
      final response = await _dio.get(
        'https://api.telegram.org/bot$_botToken/getUpdates',
        queryParameters: {
          if (_lastUpdateId != null) 'offset': _lastUpdateId! + 1,
          'timeout': 30,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ok'] && data['result'] != null) {
          for (final update in data['result']) {
            _lastUpdateId = update['update_id'];
            if (update['message'] != null) {
              final message = TelegramMessage.fromJson(update['message']);
              _messageController.add(message);
            }
          }
        }
      }
    } catch (e) {
      print('Error getting updates: $e');
    }
  }

  // Send message
  Future<bool> sendMessage(int chatId, String text) async {
    if (_botToken == null) return false;

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$_botToken/sendMessage',
        data: {
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'Markdown',
        },
      );

      return response.statusCode == 200 && response.data['ok'];
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Send reply
  Future<bool> sendReply(int chatId, int replyToMessageId, String text) async {
    if (_botToken == null) return false;

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$_botToken/sendMessage',
        data: {
          'chat_id': chatId,
          'text': text,
          'reply_to_message_id': replyToMessageId,
          'parse_mode': 'Markdown',
        },
      );

      return response.statusCode == 200 && response.data['ok'];
    } catch (e) {
      print('Error sending reply: $e');
      return false;
    }
  }

  // Send photo
  Future<bool> sendPhoto(int chatId, String photoUrl, {String? caption}) async {
    if (_botToken == null) return false;

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$_botToken/sendPhoto',
        data: {
          'chat_id': chatId,
          'photo': photoUrl,
          if (caption != null) 'caption': caption,
        },
      );

      return response.statusCode == 200 && response.data['ok'];
    } catch (e) {
      print('Error sending photo: $e');
      return false;
    }
  }

  // Get chat info
  Future<Map<String, dynamic>?> getChat(int chatId) async {
    if (_botToken == null) return null;

    try {
      final response = await _dio.get(
        'https://api.telegram.org/bot$_botToken/getChat',
        queryParameters: {'chat_id': chatId},
      );

      if (response.statusCode == 200 && response.data['ok']) {
        return response.data['result'];
      }
      return null;
    } catch (e) {
      print('Error getting chat: $e');
      return null;
    }
  }

  // Set bot commands
  Future<bool> setCommands(List<Map<String, String>> commands) async {
    if (_botToken == null) return false;

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$_botToken/setMyCommands',
        data: {
          'commands': commands
              .map((cmd) => {
                    'command': cmd['command'],
                    'description': cmd['description'],
                  })
              .toList(),
        },
      );

      return response.statusCode == 200 && response.data['ok'];
    } catch (e) {
      print('Error setting commands: $e');
      return false;
    }
  }

  void dispose() {
    stopPolling();
    _messageController.close();
  }
}
