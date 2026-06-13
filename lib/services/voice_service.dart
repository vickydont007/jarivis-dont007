import 'dart:async';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceLanguage {
  english,
  hindi,
  both,
}

class VoiceService {
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

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get statusStream => _statusController.stream;
  bool get isListening => _isListening;
  bool get isSTTAvailable => _sttAvailable;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _statusController.add('Initializing speech recognition...');

      _sttAvailable = await _speechToText.initialize(
        onError: (error) {
          print('STT Error: ${error.errorMsg}');
          _isListening = false;
          _listeningController.add(false);

          if (_isTransientError(error.errorMsg) && _retryCount < _maxRetries) {
            _retryCount++;
            final delay = Duration(milliseconds: 500 * pow(2, _retryCount - 1).toInt());
            _statusController.add('Retrying in ${delay.inSeconds}s... ($_retryCount/$_maxRetries)');
            Future.delayed(delay, () {
              if (!_isListening) startListening();
            });
          } else if (_retryCount >= _maxRetries) {
            _statusController.add('Voice recognition unavailable. Use text input.');
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

      print('STT available: $_sttAvailable');

      if (!_sttAvailable) {
        _statusController.add('Mic permission needed. Go to System Settings > Privacy & Security > Microphone.');
      }

      // Configure TTS
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;
      _statusController.add(_sttAvailable ? 'Voice ready' : 'Voice ready (mic permission needed)');
      return true;
    } catch (e) {
      print('Voice init failed: $e');
      _statusController.add('Voice init failed. Use text input.');
      return false;
    }
  }

  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (!_sttAvailable) {
      _statusController.add('STT unavailable. Grant mic permission.');
      return false;
    }

    if (_isListening) return true;

    try {
      _isListening = true;
      _listeningController.add(true);
      _statusController.add('Listening...');

      String localeId = _getLocaleId();
      print('Listening with locale: $localeId');

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

  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return List<String>.from(languages);
  }

  void dispose() {
    _transcriptionController.close();
    _listeningController.close();
    _statusController.close();
    _speechToText.cancel();
    _flutterTts.stop();
  }
}
