import 'dart:async';
import 'package:flutter/services.dart';

class ScreenContextResult {
  final bool success;
  final String? screenshotPath;
  final String? ocrText;
  final Map<String, dynamic>? uiElements;
  final String? activeApp;
  final String? error;

  ScreenContextResult({
    required this.success,
    this.screenshotPath,
    this.ocrText,
    this.uiElements,
    this.activeApp,
    this.error,
  });

  factory ScreenContextResult.fromJson(Map<String, dynamic> json) {
    return ScreenContextResult(
      success: json['success'] ?? false,
      screenshotPath: json['screenshotPath'],
      ocrText: json['ocrText'],
      uiElements: json['uiElements'],
      activeApp: json['activeApp'],
      error: json['error'],
    );
  }
}

class AccessibilityResult {
  final bool success;
  final String? focusedElement;
  final List<Map<String, dynamic>>? uiTree;
  final String? error;

  AccessibilityResult({
    required this.success,
    this.focusedElement,
    this.uiTree,
    this.error,
  });

  factory AccessibilityResult.fromJson(Map<String, dynamic> json) {
    return AccessibilityResult(
      success: json['success'] ?? false,
      focusedElement: json['focusedElement'],
      uiTree: json['uiTree'] != null
          ? List<Map<String, dynamic>>.from(json['uiTree'])
          : null,
      error: json['error'],
    );
  }
}

class ScreenContext {
  static const MethodChannel _channel = MethodChannel('com.nextron/screen_context');
  final StreamController<ScreenContextResult> _contextController =
      StreamController<ScreenContextResult>.broadcast();

  Stream<ScreenContextResult> get contextStream => _contextController.stream;

  ScreenContext() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScreenChanged':
        final result = ScreenContextResult.fromJson(Map<String, dynamic>.from(call.arguments));
        _contextController.add(result);
        break;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      return result ?? false;
    } catch (e) {
      print('Failed to check screen context permissions: $e');
      return false;
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestPermissions');
    } catch (e) {
      print('Failed to request screen context permissions: $e');
    }
  }

  Future<ScreenContextResult> captureScreen() async {
    try {
      final result = await _channel.invokeMethod('captureScreen');
      return ScreenContextResult.fromJson(Map<String, dynamic>.from(result));
    } catch (e) {
      return ScreenContextResult(
        success: false,
        error: 'Failed to capture screen: $e',
      );
    }
  }

  Future<ScreenContextResult> captureScreenWithOCR() async {
    try {
      final result = await _channel.invokeMethod('captureScreenWithOCR');
      return ScreenContextResult.fromJson(Map<String, dynamic>.from(result));
    } catch (e) {
      return ScreenContextResult(
        success: false,
        error: 'Failed to capture screen with OCR: $e',
      );
    }
  }

  Future<AccessibilityResult> getAccessibilityInfo() async {
    try {
      final result = await _channel.invokeMethod('getAccessibilityInfo');
      return AccessibilityResult.fromJson(Map<String, dynamic>.from(result));
    } catch (e) {
      return AccessibilityResult(
        success: false,
        error: 'Failed to get accessibility info: $e',
      );
    }
  }

  Future<String?> getActiveApplication() async {
    try {
      final result = await _channel.invokeMethod('getActiveApplication');
      return result;
    } catch (e) {
      print('Failed to get active application: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRunningApplications() async {
    try {
      final result = await _channel.invokeMethod('getRunningApplications');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Failed to get running applications: $e');
      return [];
    }
  }

  Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
    } catch (e) {
      print('Failed to start screen monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (e) {
      print('Failed to stop screen monitoring: $e');
    }
  }

  void dispose() {
    _contextController.close();
  }
}
