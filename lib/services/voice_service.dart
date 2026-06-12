import 'dart:async';
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

  bool _isInitialized = false;
  bool _isListening = false;
  VoiceLanguage _currentLanguage = VoiceLanguage.both;

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('Initializing speech recognition...');
      
      final available = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          _isListening = false;
          _listeningController.add(false);
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening' || status == 'cancelled') {
            _isListening = false;
            _listeningController.add(false);
          }
        },
      );

      print('Speech recognition available: $available');

      if (!available) {
        print('Speech recognition not available on this device');
        return false;
      }

      // Configure TTS
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;
      print('Speech recognition initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize voice service: $e');
      return false;
    }
  }

  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return false;
      }
    }

    if (!_isListening) {
      try {
        _isListening = true;
        _listeningController.add(true);

        String localeId = _getLocaleId();
        print('Starting to listen with locale: $localeId');

        await _speechToText.listen(
          onResult: (result) {
            print('Speech result: ${result.recognizedWords} (final: ${result.finalResult})');
            if (result.finalResult) {
              _transcriptionController.add(result.recognizedWords);
            }
          },
          localeId: localeId,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        );
        print('Listening started successfully');
        return true;
      } catch (e) {
        print('Failed to start listening: $e');
        _isListening = false;
        _listeningController.add(false);
        return false;
      }
    }
    return true;
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      _listeningController.add(false);
    }
  }

  Future<void> speak(String text, {VoiceLanguage? language}) async {
    if (!_isInitialized) {
      await initialize();
    }

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
        return 'en-US';
    }
  }

  bool _containsHindi(String text) {
    final hindiRange = RegExp(r'[\u0900-\u097F]');
    return hindiRange.hasMatch(text);
  }

  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return List<String>.from(languages);
  }

  void dispose() {
    _transcriptionController.close();
    _listeningController.close();
    _speechToText.cancel();
    _flutterTts.stop();
  }
}
