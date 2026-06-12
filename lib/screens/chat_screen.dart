import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_button.dart';
import '../providers/app_provider.dart';
import '../services/system_service.dart';
import '../core/ai_engine.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _history = [];
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
        'content': 'Hello! I am **Nextron**, your AI desktop assistant.\n\nI can help you with:\n- System control (shutdown, restart, sleep)\n- File management (read, write, search)\n- Web browsing and search\n- Code execution (Python/JS)\n- Image analysis\n- And much more!\n\nHow can I help you today?',
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

    _history.add({'role': 'user', 'content': message});

    final localResponse = await _handleLocalCommands(message);
    if (localResponse != null) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': localResponse,
          'timestamp': DateTime.now(),
        });
        _isLoading = false;
        _isTyping = false;
      });
      _history.add({'role': 'assistant', 'content': localResponse});
      _scrollToBottom();
      return;
    }

    final appState = ref.read(appStateProvider);
    String response;
    List<String> imageUrls = [];

    if (appState.isConnected && appState.aiEngine != null) {
      try {
        if (AIEngine.isImageRequest(message)) {
          final result = await appState.aiEngine!.generateImage(message);
          if (result['success'] == true) {
            response = result['content'] ?? 'Image generated!';
            if (result['imageUrls'] != null) {
              imageUrls = List<String>.from(result['imageUrls']);
            }
          } else {
            response = 'Failed to generate image: ${result['error']}';
          }
        } else {
          response = await appState.aiEngine!.sendMessage(message, history: _history);
        }
        _history.add({'role': 'assistant', 'content': response});
      } catch (e) {
        response = 'Error connecting to AI: $e\n\nPlease check your API key in Settings.';
      }
    } else {
      response = _generateMockResponse(message);
      _history.add({'role': 'assistant', 'content': response});
    }

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': response,
        'imageUrls': imageUrls,
        'timestamp': DateTime.now(),
      });
      _isLoading = false;
      _isTyping = false;
    });

    _scrollToBottom();
  }

  Future<String?> _handleLocalCommands(String message) async {
    final lowerMessage = message.toLowerCase();
    final systemService = SystemService();

    if (lowerMessage == 'yes' || lowerMessage == 'confirm') {
      return 'Confirmed. What would you like me to do?';
    }

    if (lowerMessage.contains('shutdown') || lowerMessage.contains('shut down')) {
      if (lowerMessage.contains('yes') || lowerMessage.contains('confirm')) {
        await systemService.shutdown();
        return 'Shutting down the system...';
      }
      return 'Are you sure you want to shutdown the system? Type "yes" to confirm.';
    }

    if (lowerMessage.contains('restart')) {
      if (lowerMessage.contains('yes') || lowerMessage.contains('confirm')) {
        await systemService.restart();
        return 'Restarting the system...';
      }
      return 'Are you sure you want to restart the system? Type "yes" to confirm.';
    }

    if (lowerMessage == 'sleep') {
      await systemService.sleep();
      return 'Putting the system to sleep...';
    }

    if (lowerMessage == 'lock') {
      await systemService.lock();
      return 'Locking the system...';
    }

    if (lowerMessage == 'help') {
      return '''Here are some things I can help you with:

**System Control**
- Shutdown, Restart, Sleep, Lock

**File Management**
- Read, Write, Organize files

**Weather**
- Check weather forecasts

**Social Media**
- Telegram, Discord, WhatsApp

**Voice**
- Speech to text, Text to speech

**Scheduler**
- Set reminders and alarms

**AI Features**
- Ask me anything!
- I can write code, explain concepts, and more''';
    }

    return null;
  }

  String _generateMockResponse(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('weather')) {
      return 'I can help you check the weather. Please tell me which city you want to know the weather for.';
    }

    if (lowerMessage.contains('file') || lowerMessage.contains('folder')) {
      return 'I can help you manage files. You can ask me to:\n- List files\n- Read file\n- Write file\n- Organize downloads\n- Search files';
    }

    if (lowerMessage.contains('telegram')) {
      return 'Telegram integration is available. Would you like to connect your Telegram bot?';
    }

    if (lowerMessage.contains('discord')) {
      return 'Discord integration is available. Would you like to connect your Discord bot?';
    }

    if (lowerMessage.contains('system info') || lowerMessage.contains('status')) {
      return 'Getting system information...\n\nCPU: 45%\nMemory: 62%\nDisk: 38%\nBattery: 87%';
    }

    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello! How can I assist you today?';
    }

    return 'I received your message: "$message"\n\nAI Engine not connected. Please configure your API key in Settings to get real AI responses.';
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
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          _buildHeader(appState),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.android, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nextron',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: appState.isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (appState.isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)).withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    appState.isConnected
                        ? 'Connected (${appState.provider.name})'
                        : 'Offline Mode',
                    style: TextStyle(
                      color: appState.isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (!appState.isConnected)
            _buildConfigureButton(),
        ],
      ),
    );
  }

  Widget _buildConfigureButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings, size: 16, color: Color(0xFF00BCD4)),
                SizedBox(width: 6),
                Text(
                  'Configure',
                  style: TextStyle(
                    color: Color(0xFF00BCD4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return _messages.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.android,
                  size: 64,
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Start a conversation with Nextron',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
              ],
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
                imageUrls: _messages[index]['imageUrls'] != null
                    ? List<String>.from(_messages[index]['imageUrls'])
                    : null,
              );
            },
          );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          const VoiceButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00BCD4),
                            ),
                          ),
                        )
                      : null,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
              ),
        color: _isLoading ? Colors.grey[800] : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _sendMessage,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.android, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00BCD4),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Thinking...',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
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
