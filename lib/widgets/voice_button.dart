import 'package:flutter/material.dart';
import '../services/voice_service.dart';

class VoiceButton extends StatefulWidget {
  final Function(String)? onTranscription;

  const VoiceButton({super.key, this.onTranscription});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final VoiceService _voiceService = VoiceService();

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
    
    // Listen to transcription stream
    _voiceService.transcriptionStream.listen((text) {
      if (text.isNotEmpty && widget.onTranscription != null) {
        widget.onTranscription!(text);
      }
    });
  }

  void _toggleListening() async {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    });

    if (_isListening) {
      try {
        await _voiceService.startListening();
      } catch (e) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not start voice recognition'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      await _voiceService.stopListening();
    }
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
    _voiceService.dispose();
    super.dispose();
  }
}
