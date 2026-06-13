import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';

class VoiceButton extends ConsumerStatefulWidget {
  final Function(String)? onTranscription;

  const VoiceButton({super.key, this.onTranscription});

  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _status = '';
  late AnimationController _animationController;
  late Animation<double> _animation;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService != null) {
      voiceService.transcriptionStream.listen((text) {
        if (text.isNotEmpty && widget.onTranscription != null) {
          widget.onTranscription!(text);
        }
      });
      voiceService.statusStream.listen((status) {
        if (mounted) {
          setState(() => _status = status);
        }
      });
    }
  }

  void _toggleListening() async {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;

    if (voiceService == null) {
      _showPermissionDialog();
      return;
    }

    if (!voiceService.isSTTAvailable) {
      _showPermissionDialog();
      return;
    }

    if (_isListening) {
      setState(() => _isListening = false);
      _animationController.stop();
      _animationController.reset();
      await voiceService.stopListening();
    } else {
      final started = await voiceService.startListening();
      if (started) {
        setState(() => _isListening = true);
        _animationController.repeat(reverse: true);
      } else {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
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
            const Text('Microphone Permission', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nextron needs microphone access for voice input.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Steps:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('1. Click "Open Settings" below', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  Text('2. Find "Nextron" in the list', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  Text('3. Turn ON the microphone toggle', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  Text('4. Come back and try again', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
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
    return ScaleTransition(
      scale: _animation,
      child: Tooltip(
        message: _isListening ? 'Stop listening' : (_status.isNotEmpty ? _status : 'Voice input'),
        child: Container(
          decoration: BoxDecoration(
            color: _isListening ? const Color(0xFFE53935) : const Color(0xFF1E222A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isListening ? const Color(0xFFE53935) : Theme.of(context).dividerColor,
            ),
          ),
          child: IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _toggleListening,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
