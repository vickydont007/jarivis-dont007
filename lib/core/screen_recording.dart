import 'dart:async';
import 'package:flutter/services.dart';

class RecordingInfo {
  final bool isRecording;
  final String? outputPath;
  final Duration duration;
  final DateTime? startedAt;

  RecordingInfo({
    required this.isRecording,
    this.outputPath,
    this.duration = Duration.zero,
    this.startedAt,
  });
}

class ScreenRecording {
  static const MethodChannel _channel = MethodChannel('com.nextron/screen_recording');
  final StreamController<RecordingInfo> _recordingController =
      StreamController<RecordingInfo>.broadcast();

  Stream<RecordingInfo> get recordingStream => _recordingController.stream;
  RecordingInfo _currentInfo = RecordingInfo(isRecording: false);

  ScreenRecording() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRecordingUpdate':
        _currentInfo = RecordingInfo(
          isRecording: call.arguments['isRecording'] ?? false,
          outputPath: call.arguments['outputPath'],
          duration: Duration(milliseconds: call.arguments['duration'] ?? 0),
          startedAt: call.arguments['startedAt'] != null
              ? DateTime.parse(call.arguments['startedAt'])
              : null,
        );
        _recordingController.add(_currentInfo);
        break;
    }
  }

  RecordingInfo get currentInfo => _currentInfo;

  Future<bool> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      return result ?? false;
    } catch (e) {
      print('Failed to check recording permissions: $e');
      return false;
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod('requestPermissions');
    } catch (e) {
      print('Failed to request recording permissions: $e');
    }
  }

  Future<void> startRecording({String? outputPath}) async {
    try {
      await _channel.invokeMethod('startRecording', {
        'outputPath': outputPath,
      });
    } catch (e) {
      print('Failed to start recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod('stopRecording');
      return result;
    } catch (e) {
      print('Failed to stop recording: $e');
      return null;
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _channel.invokeMethod('pauseRecording');
    } catch (e) {
      print('Failed to pause recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _channel.invokeMethod('resumeRecording');
    } catch (e) {
      print('Failed to resume recording: $e');
    }
  }

  void dispose() {
    _recordingController.close();
  }
}
