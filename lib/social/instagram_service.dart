import 'dart:async';
import 'package:dio/dio.dart';

class InstagramMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;

  InstagramMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
  });

  factory InstagramMessage.fromJson(Map<String, dynamic> json) {
    return InstagramMessage(
      id: json['id'] ?? '',
      senderId: json['sender']?['id'] ?? '',
      recipientId: json['recipient']?['id'] ?? '',
      text: json['message'] ?? '',
      timestamp: DateTime.now(),
    );
  }
}

class InstagramService {
  final Dio _dio = Dio();
  String? _accessToken;
  String? _pageId;
  final StreamController<InstagramMessage> _messageController =
      StreamController<InstagramMessage>.broadcast();

  Stream<InstagramMessage> get messageStream => _messageController.stream;

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
      print('Error sending Instagram message: $e');
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
              'payload': {'url': imageUrl, 'is_reusable': true},
            },
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending Instagram image: $e');
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
        queryParameters: {'fields': 'name,profile_pic'},
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
            final instagramMessage = InstagramMessage.fromJson(message);
            _messageController.add(instagramMessage);
          }
        }
      }
    }
  }

  void dispose() {
    _messageController.close();
  }
}
