import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';

class VoiceButton extends ConsumerStatefulWidget {
  final Function(String)? onTranscription;
  final Function(String)? onPartialTranscription;
  final VoidCallback? onListeningStart;
  final bool isEnabled;

  const VoiceButton({
    super.key,
    this.onTranscription,
    this.onPartialTranscription,
    this.onListeningStart,
    this.isEnabled = true,
  });

  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _lastText = '';
  late AnimationController _animationController;
  late Animation<double> _animation;
  StreamSubscription? _transcriptionSub;
  StreamSubscription? _finalTranscriptionSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled && oldWidget.isEnabled) {
      _cleanupListeners();
      setState(() => _isListening = false);
      _animationController.stop();
      _animationController.reset();
    }
  }

  void _setupListeners() {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService == null) return;

    _cleanupListeners();

    _transcriptionSub = voiceService.transcriptionStream.listen((text) {
      if (text.isNotEmpty && mounted) {
        _lastText = text;
        widget.onPartialTranscription?.call(text);
      }
    });
    _finalTranscriptionSub = voiceService.finalTranscriptionStream.listen((text) {
      if (text.isNotEmpty && mounted) {
        _lastText = '';
        widget.onTranscription?.call(text);
      }
    });
    _statusSub = voiceService.listeningStream.listen((listening) {
      if (!listening && mounted && _isListening) {
        setState(() => _isListening = false);
        _animationController.stop();
        _animationController.reset();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_lastText.isNotEmpty && widget.onTranscription != null) {
            widget.onTranscription!(_lastText);
            _lastText = '';
          }
        });
      }
    });
  }

  void _cleanupListeners() {
    _transcriptionSub?.cancel();
    _finalTranscriptionSub?.cancel();
    _statusSub?.cancel();
    _transcriptionSub = null;
    _finalTranscriptionSub = null;
    _statusSub = null;
  }

  void _toggleListening() async {
    if (!widget.isEnabled) return;

    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;

    if (voiceService == null) {
      _showSettingsDialog();
      return;
    }

    if (!voiceService.isSTTAvailable) {
      final granted = await voiceService.requestMicPermission();
      if (!granted || !voiceService.isSTTAvailable) {
        _showSettingsDialog();
        return;
      }
    }

    if (_isListening) {
      setState(() => _isListening = false);
      _animationController.stop();
      _animationController.reset();
      _cleanupListeners();
      await voiceService.stopListening();
    } else {
      _setupListeners();
      _lastText = '';
      voiceService.resetSession();
      widget.onListeningStart?.call();
      final started = await voiceService.startListening();
      if (started) {
        setState(() => _isListening = true);
        _animationController.repeat(reverse: true);
      } else {
        _cleanupListeners();
        _showSettingsDialog();
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mic, color: Color(0xFFFF9800), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Enable Microphone', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To use voice input, enable microphone for Nextron:',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Click "Open Settings" below', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('2. Click the lock icon and enter password', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('3. Find "nextron_ai" and turn it ON', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('4. Come back and tap mic again', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Process.run('open', [
                'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone'
              ]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled;
    final bgColor = !enabled
        ? Colors.grey[800]
        : _isListening
            ? const Color(0xFFE53935)
            : const Color(0xFF1E222A);
    final borderColor = !enabled
        ? Colors.grey[700]!
        : _isListening
            ? const Color(0xFFE53935)
            : Theme.of(context).dividerColor;

    return ScaleTransition(
      scale: _animation,
      child: Tooltip(
        message: !enabled
            ? 'Voice mode active'
            : _isListening
                ? 'Stop listening'
                : 'Voice input',
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: enabled ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            onPressed: enabled ? _toggleListening : null,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanupListeners();
    _animationController.dispose();
    super.dispose();
  }
}
