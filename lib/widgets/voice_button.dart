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
      // Check if STT is available, if not show text input
      if (!_voiceService.isSTTAvailable) {
        _showTextInputDialog();
        return;
      }

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
              content: Text('Voice recognition unavailable. Use text input.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
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
    _voiceService.dispose();
    super.dispose();
  }
}
