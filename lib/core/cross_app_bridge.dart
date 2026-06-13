import 'dart:async';
import 'package:flutter/services.dart';

class CrossAppMessage {
  final String sourceApp;
  final String targetApp;
  final String action;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CrossAppMessage({
    required this.sourceApp,
    required this.targetApp,
    required this.action,
    this.data = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'sourceApp': sourceApp,
      'targetApp': targetApp,
      'action': action,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CrossAppMessage.fromMap(Map<String, dynamic> map) {
    return CrossAppMessage(
      sourceApp: map['sourceApp'],
      targetApp: map['targetApp'],
      action: map['action'],
      data: map['data'] ?? {},
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class CrossAppBridge {
  static const MethodChannel _channel = MethodChannel('com.nextron/cross_app_bridge');
  final StreamController<CrossAppMessage> _messageController =
      StreamController<CrossAppMessage>.broadcast();

  Stream<CrossAppMessage> get messageStream => _messageController.stream;

  CrossAppBridge() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCrossAppMessage':
        final message = CrossAppMessage.fromMap(Map<String, dynamic>.from(call.arguments));
        _messageController.add(message);
        break;
    }
  }

  Future<bool> isAppInstalled(String bundleId) async {
    try {
      final result = await _channel.invokeMethod('isAppInstalled', {'bundleId': bundleId});
      return result ?? false;
    } catch (e) {
      print('Failed to check if app is installed: $e');
      return false;
    }
  }

  Future<void> openApp(String bundleId) async {
    try {
      await _channel.invokeMethod('openApp', {'bundleId': bundleId});
    } catch (e) {
      print('Failed to open app: $e');
    }
  }

  Future<void> sendMessageToApp(CrossAppMessage message) async {
    try {
      await _channel.invokeMethod('sendMessageToApp', message.toMap());
    } catch (e) {
      print('Failed to send message to app: $e');
    }
  }

  Future<Map<String, dynamic>> getAppInfo(String bundleId) async {
    try {
      final result = await _channel.invokeMethod('getAppInfo', {'bundleId': bundleId});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Failed to get app info: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod('getInstalledApps');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Failed to get installed apps: $e');
      return [];
    }
  }

  Future<void> sendClipboardData(String data, String sourceApp) async {
    try {
      await _channel.invokeMethod('sendClipboardData', {
        'data': data,
        'sourceApp': sourceApp,
      });
    } catch (e) {
      print('Failed to send clipboard data: $e');
    }
  }

  Future<String?> getClipboardData() async {
    try {
      final result = await _channel.invokeMethod('getClipboardData');
      return result;
    } catch (e) {
      print('Failed to get clipboard data: $e');
      return null;
    }
  }

  void dispose() {
    _messageController.close();
  }
}
