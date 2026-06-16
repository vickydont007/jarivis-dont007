import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/orb_state_manager.dart';

enum VoiceLanguage {
  english,
  hindi,
  both,
}

enum VoiceMode {
  idle,
  listening,
  processing,
  speaking,
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
  final StreamController<VoiceMode> _voiceModeController =
      StreamController<VoiceMode>.broadcast();

  final OrbStateManager? _orb;
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _sttAvailable = false;
  String _micPermission = 'not_determined';
  VoiceLanguage _currentLanguage = VoiceLanguage.both;
  String _lastFinalText = '';
  int _lastFinalWordCount = 0;

  // Voice settings
  bool _autoSpeak = true;
  bool _wakeWordEnabled = false;
  double _speechRate = 0.5;
  bool _conversationMode = false;
  VoiceMode _voiceMode = VoiceMode.idle;

  // Conversation mode subscriptions
  StreamSubscription? _ttsCompletionSub;
  StreamSubscription? _finalTranscriptionSub;

  static const String _wakeWord = 'hey jarvis';
  static const List<String> _wakeWordVariants = [
    'hey jarvis',
    'hey jarvis',
    'hey jarbis',
    'hey jars',
    'hey j',
  ];

  VoiceService({OrbStateManager? orb}) : _orb = orb;

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<String> get finalTranscriptionStream => _finalTranscriptionController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<void> get ttsCompletionStream => _ttsCompletionController.stream;
  Stream<VoiceMode> get voiceModeStream => _voiceModeController.stream;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isSTTAvailable => _sttAvailable;
  String get micPermission => _micPermission;
  bool get autoSpeak => _autoSpeak;
  bool get wakeWordEnabled => _wakeWordEnabled;
  double get speechRate => _speechRate;
  bool get conversationMode => _conversationMode;
  VoiceMode get voiceMode => _voiceMode;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _statusController.add('Checking permissions...');
      _micPermission = await _checkPermission();

      if (_micPermission == 'not_determined') {
        _micPermission = await _requestPermission();
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

      // Load saved settings
      await _loadSettings();

      // Listen for native speech results
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSpeechResult') {
          final args = call.arguments as Map;
          final rawText = args['text'] as String? ?? '';
          final isFinal = args['isFinal'] as bool? ?? false;
          if (rawText.isNotEmpty) {
            String cleanText = rawText;
            if (_lastFinalWordCount > 0) {
              final words = rawText.split(RegExp(r'\s+'));
              if (words.length > _lastFinalWordCount) {
                cleanText = words.sublist(_lastFinalWordCount).join(' ');
              }
            }
            if (cleanText.isEmpty) cleanText = rawText;

            // Check for wake word in non-final results
            if (!isFinal && _wakeWordEnabled && !_isListening) {
              if (_containsWakeWord(cleanText)) {
                _onWakeWordDetected();
              }
            }

            if (isFinal) {
              _lastFinalText = cleanText;
              _lastFinalWordCount = cleanText.split(RegExp(r'\s+')).length;
              _finalTranscriptionController.add(cleanText);
            } else {
              _transcriptionController.add(cleanText);
            }
          }
          if (isFinal) {
            _lastFinalWordCount = 0;
            _isListening = false;
            _listeningController.add(false);
            _updateVoiceMode(VoiceMode.processing);
            _statusController.add('Processing...');
          }
        }
      });

      // Configure TTS
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _orb?.releaseSpeaking('voice');
        _ttsCompletionController.add(null);
        _updateVoiceMode(VoiceMode.idle);
        _statusController.add('Speech complete');

        // If conversation mode, restart listening after TTS completes
        if (_conversationMode) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_conversationMode) {
              startListening();
            }
          });
        }
      });

      await loadSavedVoice();

      return true;
    } catch (e) {
      _statusController.add('Voice init failed.');
      return false;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSpeak = prefs.getBool('voice_auto_speak') ?? true;
      _wakeWordEnabled = prefs.getBool('voice_wake_word') ?? false;
      _speechRate = prefs.getDouble('voice_speech_rate') ?? 0.5;
      _conversationMode = prefs.getBool('voice_conversation_mode') ?? false;
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_auto_speak', _autoSpeak);
      await prefs.setBool('voice_wake_word', _wakeWordEnabled);
      await prefs.setDouble('voice_speech_rate', _speechRate);
      await prefs.setBool('voice_conversation_mode', _conversationMode);
    } catch (_) {}
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
        _updateVoiceMode(VoiceMode.listening);
        _statusController.add('Listening...');
        _orb?.requestListening('voice');
        return true;
      } else {
        _statusController.add('Failed: $result');
        return false;
      }
    } catch (e) {
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
      _orb?.releaseListening('voice');
      if (!_isSpeaking) {
        _updateVoiceMode(VoiceMode.idle);
      }
    }
  }

  void resetSession() {
    _lastFinalText = '';
    _lastFinalWordCount = 0;
  }

  // ─── Conversation Mode ────────────────────────────────────────

  Future<void> startConversationMode() async {
    _conversationMode = true;
    await _saveSettings();
    resetSession();
    await startListening();
  }

  Future<void> stopConversationMode() async {
    _conversationMode = false;
    await _saveSettings();
    await stopListening();
    await stopSpeaking();
    _updateVoiceMode(VoiceMode.idle);
  }

  // ─── Wake Word Detection ──────────────────────────────────────

  bool _containsWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    for (final variant in _wakeWordVariants) {
      if (lower.contains(variant)) return true;
    }
    return false;
  }

  void _onWakeWordDetected() {
    _statusController.add('Wake word detected!');
    stopListening();
    Future.delayed(const Duration(milliseconds: 300), () {
      startListening();
    });
  }

  // ─── Settings ─────────────────────────────────────────────────

  Future<void> setAutoSpeak(bool enabled) async {
    _autoSpeak = enabled;
    await _saveSettings();
  }

  Future<void> setWakeWordEnabled(bool enabled) async {
    _wakeWordEnabled = enabled;
    await _saveSettings();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
    await _saveSettings();
  }

  // ─── Voice Mode ───────────────────────────────────────────────

  void _updateVoiceMode(VoiceMode mode) {
    _voiceMode = mode;
    _voiceModeController.add(mode);
  }

  // ─── TTS ──────────────────────────────────────────────────────

  static const List<Map<String, String>> femaleVoices = [
    {'name': 'Samantha', 'locale': 'en-US'},
    {'name': 'Karen', 'locale': 'en-AU'},
    {'name': 'Moira', 'locale': 'en-IE'},
    {'name': 'Tessa', 'locale': 'en-ZA'},
    {'name': 'Victoria', 'locale': 'en-US'},
  ];

  static const List<Map<String, String>> allVoices = [
    {'name': 'Samantha', 'locale': 'en-US'},
    {'name': 'Karen', 'locale': 'en-AU'},
    {'name': 'Moira', 'locale': 'en-IE'},
    {'name': 'Tessa', 'locale': 'en-ZA'},
    {'name': 'Victoria', 'locale': 'en-US'},
    {'name': 'Alex', 'locale': 'en-US'},
    {'name': 'Daniel', 'locale': 'en-GB'},
    {'name': 'Tom', 'locale': 'en-US'},
  ];

  Future<void> loadSavedVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVoiceName = prefs.getString('tts_voice_name') ?? 'Samantha';
      final savedVoiceLocale = prefs.getString('tts_voice_locale') ?? 'en-US';
      if (!_isInitialized) await initialize();
      await _flutterTts.setVoice({'name': savedVoiceName, 'locale': savedVoiceLocale});
    } catch (e) {
      print('Failed to load saved voice: $e');
    }
  }

  Future<void> setVoiceByName(String name, String locale) async {
    if (!_isInitialized) await initialize();
    try {
      await _flutterTts.setVoice({'name': name, 'locale': locale});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tts_voice_name', name);
      await prefs.setString('tts_voice_locale', locale);
    } catch (e) {
      print('Failed to set voice: $e');
    }
  }

  Future<void> speak(String text, {VoiceLanguage? language}) async {
    if (!_isInitialized) await initialize();

    // If already speaking, stop first (interrupt)
    if (_isSpeaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isSpeaking = true;
    _orb?.requestSpeaking('voice');
    _updateVoiceMode(VoiceMode.speaking);

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
    _isSpeaking = false;
    _orb?.releaseSpeaking('voice');
    _ttsCompletionController.add(null);
  }

  void setLanguage(VoiceLanguage language) {
    _currentLanguage = language;
  }

  bool _containsHindi(String text) {
    final hindiRange = RegExp(r'[\u0900-\u097F]');
    return hindiRange.hasMatch(text);
  }

  String stripMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'^#+\s', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'^[-*]\s', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s', multiLine: true), '')
        .trim();
  }

  void dispose() {
    _ttsCompletionSub?.cancel();
    _finalTranscriptionSub?.cancel();
    _transcriptionController.close();
    _finalTranscriptionController.close();
    _listeningController.close();
    _statusController.close();
    _ttsCompletionController.close();
    _voiceModeController.close();
    _flutterTts.stop();
  }
}
