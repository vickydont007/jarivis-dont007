import 'dart:async';
import 'package:dio/dio.dart';

class WhatsAppMessage {
  final String id;
  final String from;
  final String to;
  final String text;
  final DateTime timestamp;
  final String status;

  WhatsAppMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.timestamp,
    this.status = 'sent',
  });

  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessage(
      id: json['id'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.now(),
      status: json['status'] ?? 'sent',
    );
  }
}

class WhatsAppService {
  final Dio _dio = Dio();
  String? _accessToken;
  String? _phoneNumberId;
  String? _businessAccountId;
  final StreamController<WhatsAppMessage> _messageController =
      StreamController<WhatsAppMessage>.broadcast();

  Stream<WhatsAppMessage> get messageStream => _messageController.stream;

  void setCredentials({
    required String accessToken,
    required String phoneNumberId,
    required String businessAccountId,
  }) {
    _accessToken = accessToken;
    _phoneNumberId = phoneNumberId;
    _businessAccountId = businessAccountId;
  }

  // Send message
  Future<bool> sendMessage(String to, String message) async {
    if (_accessToken == null || _phoneNumberId == null) {
      throw Exception('Credentials not set');
    }

    try {
      final response = await _dio.post(
        'https://graph.facebook.com/v18.0/$_phoneNumberId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'messaging_product': 'whatsapp',
          'to': to,
          'type': 'text',
          'text': {
            'body': message,
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending WhatsApp message: $e');
      return false;
    }
  }

  // Send template message
  Future<bool> sendTemplate({
    required String to,
    required String templateName,
    required String languageCode,
    List<Map<String, dynamic>>? components,
  }) async {
    if (_accessToken == null || _phoneNumberId == null) {
      throw Exception('Credentials not set');
    }

    try {
      final response = await _dio.post(
        'https://graph.facebook.com/v18.0/$_phoneNumberId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'messaging_product': 'whatsapp',
          'to': to,
          'type': 'template',
          'template': {
            'name': templateName,
            'language': {
              'code': languageCode,
            },
            if (components != null) 'components': components,
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending WhatsApp template: $e');
      return false;
    }
  }

  // Send image
  Future<bool> sendImage(String to, String imageUrl, {String? caption}) async {
    if (_accessToken == null || _phoneNumberId == null) {
      throw Exception('Credentials not set');
    }

    try {
      final response = await _dio.post(
        'https://graph.facebook.com/v18.0/$_phoneNumberId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'messaging_product': 'whatsapp',
          'to': to,
          'type': 'image',
          'image': {
            'link': imageUrl,
            if (caption != null) 'caption': caption,
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending WhatsApp image: $e');
      return false;
    }
  }

  // Get message status
  Future<Map<String, dynamic>?> getMessageStatus(String messageId) async {
    if (_accessToken == null) return null;

    try {
      final response = await _dio.get(
        'https://graph.facebook.com/v18.0/$messageId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error getting message status: $e');
      return null;
    }
  }

  // Webhook verification
  String verifyWebhook(String hubMode, String hubChallenge, String hubVerifyToken) {
    if (hubMode == 'subscribe' && hubVerifyToken == _accessToken) {
      return hubChallenge;
    }
    throw Exception('Webhook verification failed');
  }

  // Handle incoming webhook
  void handleWebhook(Map<String, dynamic> payload) {
    if (payload['entry'] != null) {
      for (final entry in payload['entry']) {
        if (entry['changes'] != null) {
          for (final change in entry['changes']) {
            if (change['value'] != null && change['value']['messages'] != null) {
              for (final message in change['value']['messages']) {
                final whatsappMessage = WhatsAppMessage.fromJson(message);
                _messageController.add(whatsappMessage);
              }
            }
          }
        }
      }
    }
  }

  void dispose() {
    _messageController.close();
  }
}
