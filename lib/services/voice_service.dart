import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceLanguage {
  english,
  hindi,
  both,
}

class VoiceService {
  static const _channel = MethodChannel('com.nextron.ai/mic_permission');
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  bool _isInitialized = false;
  bool _isListening = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  VoiceLanguage _currentLanguage = VoiceLanguage.both;
  bool _sttAvailable = false;
  String _micPermission = 'not_determined';

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get statusStream => _statusController.stream;
  bool get isListening => _isListening;
  bool get isSTTAvailable => _sttAvailable;
  String get micPermission => _micPermission;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _statusController.add('Checking permissions...');

      // Check current status
      _micPermission = await _checkPermission();
      print('Permission status: $_micPermission');

      // Request if not determined
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

      // Init STT
      _statusController.add('Initializing speech recognition...');
      try {
        _sttAvailable = await _speechToText.initialize(
          onError: (error) {
            print('STT Error: ${error.errorMsg}');
            _isListening = false;
            _listeningController.add(false);

            if (_isTransientError(error.errorMsg) && _retryCount < _maxRetries) {
              _retryCount++;
              final delay = Duration(milliseconds: 500 * pow(2, _retryCount - 1).toInt());
              Future.delayed(delay, () {
                if (!_isListening) startListening();
              });
            }
          },
          onStatus: (status) {
            print('STT Status: $status');
            if (status == 'done' || status == 'notListening' || status == 'cancelled') {
              _isListening = false;
              _listeningController.add(false);
            }
            if (status == 'listening') {
              _retryCount = 0;
            }
          },
        );
      } catch (e) {
        print('STT init error: $e');
        _sttAvailable = false;
      }

      // Configure TTS
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;

      if (_sttAvailable) {
        _statusController.add('Voice ready');
      } else {
        _statusController.add('STT unavailable');
      }

      return _sttAvailable;
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
      _isListening = true;
      _listeningController.add(true);
      _statusController.add('Listening...');

      String localeId = _getLocaleId();

      await _speechToText.listen(
        onResult: (result) {
          print('STT Result: ${result.recognizedWords} (final: ${result.finalResult})');
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _transcriptionController.add(result.recognizedWords);
            _retryCount = 0;
          }
        },
        localeId: localeId,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      );
      return true;
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
      await _speechToText.stop();
      _isListening = false;
      _listeningController.add(false);
      _statusController.add('Stopped');
    }
  }

  Future<void> speak(String text, {VoiceLanguage? language}) async {
    if (!_isInitialized) await initialize();

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

  String _getLocaleId() {
    switch (_currentLanguage) {
      case VoiceLanguage.english:
        return 'en-US';
      case VoiceLanguage.hindi:
        return 'hi-IN';
      case VoiceLanguage.both:
        return 'hi-IN';
    }
  }

  bool _containsHindi(String text) {
    final hindiRange = RegExp(r'[\u0900-\u097F]');
    return hindiRange.hasMatch(text);
  }

  bool _isTransientError(String? errorMsg) {
    if (errorMsg == null) return false;
    const transientErrors = ['error_busy', 'error_server', 'network'];
    return transientErrors.any((e) => errorMsg.toLowerCase().contains(e));
  }

  void dispose() {
    _transcriptionController.close();
    _listeningController.close();
    _statusController.close();
    _speechToText.cancel();
    _flutterTts.stop();
  }
}
