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
    // Listen to transcription stream from shared voice service
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService != null) {
      voiceService.transcriptionStream.listen((text) {
        if (text.isNotEmpty && widget.onTranscription != null) {
          widget.onTranscription!(text);
        }
      });
    }
  }

  void _toggleListening() async {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;

    if (voiceService == null || !voiceService.isSTTAvailable) {
      _showTextInputDialog();
      return;
    }

    if (_isListening) {
      setState(() {
        _isListening = false;
        _animationController.stop();
        _animationController.reset();
      });
      await voiceService.stopListening();
    } else {
      final started = await voiceService.startListening();
      if (started) {
        setState(() {
          _isListening = true;
          _animationController.repeat(reverse: true);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Speech recognition unavailable. Grant permission in System Settings > Privacy & Security > Microphone.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open Settings',
                textColor: Colors.white,
                onPressed: () async {
                  // Open macOS System Settings
                  await Process.run('open', ['x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone']);
                },
              ),
            ),
          );
          _showTextInputDialog();
        }
      }
    }
  }

  void _showTextInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Text Input', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Type your message...',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty && widget.onTranscription != null) {
              widget.onTranscription!(value);
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty && widget.onTranscription != null) {
                widget.onTranscription!(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        decoration: BoxDecoration(
          color: _isListening ? Colors.red : const Color(0xFF30363D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
          ),
          onPressed: _toggleListening,
          tooltip: _isListening ? 'Stop listening' : 'Start listening',
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
