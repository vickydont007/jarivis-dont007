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
    
    _voiceService.transcriptionStream.listen((text) {
      if (text.isNotEmpty && widget.onTranscription != null) {
        widget.onTranscription!(text);
      }
    });
  }

  void _toggleListening() async {
    if (_isListening) {
      setState(() {
        _isListening = false;
        _animationController.stop();
        _animationController.reset();
      });
      await _voiceService.stopListening();
    } else {
      final started = await _voiceService.startListening();
      if (started) {
        setState(() {
          _isListening = true;
          _animationController.repeat(reverse: true);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not start voice recognition. Please check microphone permissions.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
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
