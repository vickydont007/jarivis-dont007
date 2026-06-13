import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceLanguage {
  english,
  hindi,
  both,
}

class VoiceService {
  static const _channel = MethodChannel('com.nextron.ai/mic_permission');
  final FlutterTts _flutterTts = FlutterTts();
  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<String> _finalTranscriptionController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<void> _ttsCompletionController =
      StreamController<void>.broadcast();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _sttAvailable = false;
  String _micPermission = 'not_determined';
  VoiceLanguage _currentLanguage = VoiceLanguage.both;

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<String> get finalTranscriptionStream => _finalTranscriptionController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<void> get ttsCompletionStream => _ttsCompletionController.stream;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isSTTAvailable => _sttAvailable;
  String get micPermission => _micPermission;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _statusController.add('Checking permissions...');
      _micPermission = await _checkPermission();
      print('Permission status: $_micPermission');

      if (_micPermission == 'not_determined') {
        _micPermission = await _requestPermission();
        print('Permission after request: $_micPermission');
      }

      if (_micPermission != 'authorized') {
        _sttAvailable = false;
        _isInitialized = true;
        _statusController.add('Permission denied');
        return false;
      }

      _sttAvailable = true;
      _isInitialized = true;
      _statusController.add('Voice ready');

      // Listen for native speech results
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSpeechResult') {
          final args = call.arguments as Map;
          final text = args['text'] as String? ?? '';
          final isFinal = args['isFinal'] as bool? ?? false;
          if (text.isNotEmpty) {
            if (isFinal) {
              _finalTranscriptionController.add(text);
            } else {
              _transcriptionController.add(text);
            }
          }
          if (isFinal) {
            _isListening = false;
            _listeningController.add(false);
            _statusController.add('Stopped');
          }
        }
      });

      // Configure TTS
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _ttsCompletionController.add(null);
        _statusController.add('Speech complete');
      });

      return true;
    } catch (e) {
      print('Voice init failed: $e');
      _statusController.add('Voice init failed.');
      return false;
    }
  }

  Future<String> _checkPermission() async {
    try {
      final result = await _channel.invokeMethod('checkPermission');
      return result ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  Future<String> _requestPermission() async {
    try {
      final result = await _channel.invokeMethod('requestPermission');
      return result ?? 'denied';
    } catch (e) {
      return 'denied';
    }
  }

  Future<bool> requestMicPermission() async {
    _micPermission = await _requestPermission();
    if (_micPermission == 'authorized') {
      _isInitialized = false;
      _sttAvailable = false;
      await initialize();
      return true;
    }
    return false;
  }

  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (!_sttAvailable) {
      _statusController.add('STT unavailable.');
      return false;
    }

    if (_isListening) return true;

    try {
      final result = await _channel.invokeMethod('startListening');
      if (result == 'started') {
        _isListening = true;
        _listeningController.add(true);
        _statusController.add('Listening...');
        return true;
      } else {
        _statusController.add('Failed: $result');
        return false;
      }
    } catch (e) {
      print('STT listen failed: $e');
      _isListening = false;
      _listeningController.add(false);
      _statusController.add('Failed to start listening.');
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _channel.invokeMethod('stopListening');
      } catch (e) {}
      _isListening = false;
      _listeningController.add(false);
      _statusController.add('Stopped');
    }
  }

  Future<void> speak(String text, {VoiceLanguage? language}) async {
    if (!_isInitialized) await initialize();

    _isSpeaking = true;
    final lang = language ?? _currentLanguage;
    switch (lang) {
      case VoiceLanguage.english:
        await _flutterTts.setLanguage('en-US');
        break;
      case VoiceLanguage.hindi:
        await _flutterTts.setLanguage('hi-IN');
        break;
      case VoiceLanguage.both:
        if (_containsHindi(text)) {
          await _flutterTts.setLanguage('hi-IN');
        } else {
          await _flutterTts.setLanguage('en-US');
        }
        break;
    }
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  void setLanguage(VoiceLanguage language) {
    _currentLanguage = language;
  }

  bool _containsHindi(String text) {
    final hindiRange = RegExp(r'[\u0900-\u097F]');
    return hindiRange.hasMatch(text);
  }

  void dispose() {
    _transcriptionController.close();
    _finalTranscriptionController.close();
    _listeningController.close();
    _statusController.close();
    _ttsCompletionController.close();
    _flutterTts.stop();
  }
}
