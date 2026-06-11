import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': 'Hello! I am Jarvis, your AI desktop assistant. How can I help you today?',
        'timestamp': DateTime.now(),
      });
    });
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'content': message,
        'timestamp': DateTime.now(),
      });
      _messageController.clear();
      _isLoading = true;
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate AI response (will be replaced with actual AI engine)
    await Future.delayed(const Duration(seconds: 2));

    final response = _generateResponse(message);

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': response,
        'timestamp': DateTime.now(),
      });
      _isLoading = false;
      _isTyping = false;
    });

    _scrollToBottom();
  }

  String _generateResponse(String message) {
    final lowerMessage = message.toLowerCase();

    // System commands
    if (lowerMessage.contains('shutdown') || lowerMessage.contains('shut down')) {
      return '⚠️ Are you sure you want to shutdown the system? Please confirm.';
    }
    if (lowerMessage.contains('restart')) {
      return '⚠️ Are you sure you want to restart the system? Please confirm.';
    }
    if (lowerMessage.contains('sleep')) {
      return '😴 Putting the system to sleep...';
    }
    if (lowerMessage.contains('lock')) {
      return '🔒 Locking the system...';
    }

    // Weather
    if (lowerMessage.contains('weather')) {
      return '🌤️ I can help you check the weather. Please tell me which city you want to know the weather for.';
    }

    // File operations
    if (lowerMessage.contains('file') || lowerMessage.contains('folder')) {
      return '📁 I can help you manage files. You can ask me to:\n- List files\n- Read file\n- Write file\n- Organize downloads\n- Search files';
    }

    // Social media
    if (lowerMessage.contains('telegram')) {
      return '📱 Telegram integration is available. Would you like to connect your Telegram bot?';
    }
    if (lowerMessage.contains('discord')) {
      return '🎮 Discord integration is available. Would you like to connect your Discord bot?';
    }

    // System info
    if (lowerMessage.contains('system info') || lowerMessage.contains('status')) {
      return '💻 Getting system information...\n\nCPU: 45%\nMemory: 62%\nDisk: 38%\nBattery: 87%';
    }

    // Default responses
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello! How can I assist you today?';
    }
    if (lowerMessage.contains('help')) {
      return 'Here are some things I can help you with:\n\n🖥️ **System Control**\n- Shutdown, Restart, Sleep, Lock\n\n📁 **File Management**\n- Read, Write, Organize files\n\n🌤️ **Weather**\n- Check weather forecasts\n\n📱 **Social Media**\n- Telegram, Discord, WhatsApp\n\n🎤 **Voice**\n- Speech to text, Text to speech\n\n⏰ **Scheduler**\n- Set reminders and alarms';
    }

    return 'I received your message: "$message"\n\nI am currently in development mode. Full AI integration will be available soon!';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF30363D),
                ),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.cyan,
                  child: Icon(Icons.android, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jarvis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  onPressed: () {
                    // Navigate to settings
                  },
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation with Jarvis',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return ChatBubble(
                        message: _messages[index]['content'],
                        isUser: _messages[index]['role'] == 'user',
                        timestamp: _messages[index]['timestamp'],
                      );
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(
                top: BorderSide(
                  color: Color(0xFF30363D),
                ),
              ),
            ),
            child: Row(
              children: [
                // Voice button
                const VoiceButton(),
                const SizedBox(width: 12),

                // Message input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF30363D),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.cyan,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.cyan,
            child: Icon(Icons.android, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.cyan,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Jarvis is typing...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
