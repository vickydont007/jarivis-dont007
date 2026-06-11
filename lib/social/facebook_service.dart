import 'dart:async';
import 'package:dio/dio.dart';

class FacebookMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;

  FacebookMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
  });

  factory FacebookMessage.fromJson(Map<String, dynamic> json) {
    return FacebookMessage(
      id: json['message_id'] ?? '',
      senderId: json['sender']?['id'] ?? '',
      recipientId: json['recipient']?['id'] ?? '',
      text: json['message']?['text'] ?? '',
      timestamp: DateTime.now(),
    );
  }
}

class FacebookService {
  final Dio _dio = Dio();
  String? _accessToken;
  String? _pageId;
  final StreamController<FacebookMessage> _messageController =
      StreamController<FacebookMessage>.broadcast();

  Stream<FacebookMessage> get messageStream => _messageController.stream;

  void setCredentials({required String accessToken, required String pageId}) {
    _accessToken = accessToken;
    _pageId = pageId;
  }

  // Send message
  Future<bool> sendMessage(String recipientId, String message) async {
    if (_accessToken == null || _pageId == null) {
      throw Exception('Credentials not set');
    }

    try {
      final response = await _dio.post(
        'https://graph.facebook.com/v18.0/$_pageId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'recipient': {'id': recipientId},
          'message': {'text': message},
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending Facebook message: $e');
      return false;
    }
  }

  // Send image
  Future<bool> sendImage(String recipientId, String imageUrl) async {
    if (_accessToken == null || _pageId == null) {
      throw Exception('Credentials not set');
    }

    try {
      final response = await _dio.post(
        'https://graph.facebook.com/v18.0/$_pageId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'recipient': {'id': recipientId},
          'message': {
            'attachment': {
              'type': 'image',
              'payload': {'url': imageUrl},
            },
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending Facebook image: $e');
      return false;
    }
  }

  // Send quick reply
  Future<bool> sendQuickReply({
    required String recipientId,
    required String text,
    required List<Map<String, String>> quickReplies,
  }) async {
    if (_accessToken == null || _pageId == null) {
      throw Exception('Credentials not set');
    }

    try {
      final response = await _dio.post(
        'https://graph.facebook.com/v18.0/$_pageId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'recipient': {'id': recipientId},
          'messaging_type': 'RESPONSE',
          'message': {
            'text': text,
            'quick_replies': quickReplies
                .map((qr) => {
                      'content_type': 'text',
                      'title': qr['title'],
                      'payload': qr['payload'],
                    })
                .toList(),
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending Facebook quick reply: $e');
      return false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (_accessToken == null) return null;

    try {
      final response = await _dio.get(
        'https://graph.facebook.com/v18.0/$userId',
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
        queryParameters: {'fields': 'first_name,last_name,profile_pic'},
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Handle webhook
  void handleWebhook(Map<String, dynamic> payload) {
    if (payload['entry'] != null) {
      for (final entry in payload['entry']) {
        if (entry['messaging'] != null) {
          for (final message in entry['messaging']) {
            final facebookMessage = FacebookMessage.fromJson(message);
            _messageController.add(facebookMessage);
          }
        }
      }
    }
  }

  void dispose() {
    _messageController.close();
  }
}
