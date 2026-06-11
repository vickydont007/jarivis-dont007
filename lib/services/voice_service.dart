import '../core/logger.dart';
import 'terminal_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final JarvisLogger _log = JarvisLogger();
  final TerminalService _terminal = TerminalService();

  bool _isListening = false;

  bool get isListening => _isListening;

  Future<void> say(String text) async {
    _log.info('TTS: $text');
    final cmd = _terminal.run(
      'powershell -Command "Add-Type -AssemblyName System.Speech; '
      '\$synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
      '\$synthesizer.Speak(\'$text\')"',
      timeout: 60000,
    );
    // Non-blocking
  }

  Future<String> listen({int timeout = 10}) async {
    _isListening = true;
    _log.info('Listening for voice input...');

    try {
      final result = await _terminal.run(
        'powershell -Command "
          Add-Type -AssemblyName System.Speech;
          \$recognizer = New-Object System.Speech.Recognition.SpeechRecognizer;
          \$recognizer.SetInputToDefaultAudioDevice();
          \$result = \$recognizer.Recognize();
          if (\$result -ne \$null) { Write-Output \$result.Text } else { Write-Output '' }
        "',
        timeout: timeout * 1000 + 5000,
      );

      _isListening = false;
      return result.success ? result.stdout.trim() : '';
    } catch (e) {
      _isListening = false;
      _log.error('Voice recognition failed', exception: e);
      return '';
    }
  }

  Future<bool> isMicrophoneAvailable() async {
    final result = await _terminal.run(
      'powershell -Command "
        Add-Type -AssemblyName System.Speech;
        \$recognizer = New-Object System.Speech.Recognition.SpeechRecognizer;
        Write-Output \$recognizer.State
      "',
      timeout: 5000,
    );
    return result.success;
  }
}
