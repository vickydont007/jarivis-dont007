import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_button.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../core/ai_engine.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<PlatformFile> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
  }

  void _pickFiles({bool foldersOnly = false}) async {
    try {
      if (foldersOnly) {
        final result = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Folder',
        );
        if (result != null) {
          setState(() {
            _attachedFiles.add(PlatformFile(
              name: result.split('/').last,
              path: result,
              size: 0,
            ));
          });
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          dialogTitle: 'Select Files',
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _attachedFiles.addAll(result.files);
          });
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file, color: Color(0xFF00BCD4), size: 22),
                ),
                title: const Text('Attach Files', style: TextStyle(color: Colors.white)),
                subtitle: Text('Select files to share', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(foldersOnly: false);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder, color: Color(0xFF4CAF50), size: 22),
                ),
                title: const Text('Attach Folder', style: TextStyle(color: Colors.white)),
                subtitle: Text('Select a folder to share', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(foldersOnly: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  String _getFileSize(PlatformFile file) {
    if (file.size == 0) return '📁 Folder';
    if (file.size < 1024) return '${file.size} B';
    if (file.size < 1024 * 1024) return '${(file.size / 1024).toStringAsFixed(1)} KB';
    return '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _sendMessage() async {
    String message = _messageController.text.trim();

    // Include attached files in message
    if (_attachedFiles.isNotEmpty) {
      final fileLines = _attachedFiles.map((f) => '📎 ${f.name} (${_getFileSize(f)})\n📂 ${f.path}').join('\n');
      if (message.isEmpty) {
        message = 'Attached files:\n$fileLines';
      } else {
        message = '$message\n\nAttached files:\n$fileLines';
      }
    }

    if (message.isEmpty) return;

    ref.read(chatProvider.notifier).addUserMessage(message);
    _messageController.clear();
    setState(() {
      _attachedFiles.clear();
    });

    _scrollToBottom();

    final localResponse = await _handleLocalCommands(message);
    if (localResponse != null) {
      ref.read(chatProvider.notifier).addAssistantMessage(localResponse);
      _scrollToBottom();
      return;
    }

    final appState = ref.read(appStateProvider);
    final chatState = ref.read(chatProvider);
    final cancelToken = chatState.cancelToken;
    String response;
    List<String> imageUrls = [];

    if (appState.isConnected && appState.aiEngine != null) {
      try {
        if (AIEngine.isImageRequest(message)) {
          final result = await appState.aiEngine!.generateImage(message);
          if (result['success'] == true) {
            imageUrls = List<String>.from(result['imageUrls'] ?? []);
            response = result['text'] ?? 'Here is the generated image.';
          } else {
            response = result['error'] ?? 'Failed to generate image.';
          }
        } else {
          final history = ref.read(chatProvider).messages
              .where((m) => m.role != 'system')
              .map((m) => {'role': m.role, 'content': m.content})
              .toList();

          final toolManager = appState.toolManager;
          if (toolManager != null) {
            final result = await appState.aiEngine!.sendMessageWithTools(
              message,
              history: history,
              onToolCall: (name, args) async {
                ref.read(chatProvider.notifier).addAssistantMessage('🔧 Using $name...');
                _scrollToBottom();
                return await toolManager.executeTool(name, args);
              },
              cancelToken: cancelToken,
            );
            response = result['response'] ?? 'No response';
            if (result['error'] != null) {
              response = 'Error: ${result['error']}';
            }
          } else {
            response = await appState.aiEngine!.sendMessage(message, history: history);
          }
        }
      } catch (e) {
        response = 'Error: $e';
      }
    } else {
      response = 'Not connected. Please check your API key in Settings.';
    }

    if (cancelToken != null && cancelToken.isCancelled) return;

    ref.read(chatProvider.notifier).addAssistantMessage(response, imageUrls: imageUrls);
    _scrollToBottom();
  }

  Future<String?> _handleLocalCommands(String message) async {
    final lower = message.toLowerCase().trim();

    if (lower == 'system info' || lower == 'systeminfo') {
      final appState = ref.read(appStateProvider);
      final toolManager = appState.toolManager;
      if (toolManager != null) {
        final result = await toolManager.executeTool('system_info', {});
        return result.toDisplayString();
      }
      return 'System service not available';
    }

    if (lower == 'help') {
      return 'Available commands:\n'
          '- system info: Get system information\n'
          '- help: Show this help\n\n'
          'You can also:\n'
          '- Ask me anything\n'
          '- Generate images\n'
          '- Attach files with 📎 button\n'
          '- Use natural language commands';
    }

    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final chatState = ref.watch(chatProvider);

    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.android,
                          size: 48,
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hello! I am Nextron',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'How can I help you today?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chatState.messages.length) {
                      return _buildTypingIndicator();
                    }
                    return ChatBubble(
                      message: chatState.messages[index].content,
                      isUser: chatState.messages[index].role == 'user',
                      timestamp: chatState.messages[index].timestamp,
                      imageUrls: chatState.messages[index].imageUrls,
                    );
                  },
                ),
        ),
        if (_attachedFiles.isNotEmpty) _buildFileChips(),
        _buildInputArea(chatState),
      ],
    );
  }

  Widget _buildFileChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachedFiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final file = _attachedFiles[index];
            final isFolder = file.size == 0;
            return Chip(
              avatar: Icon(
                isFolder ? Icons.folder : Icons.insert_drive_file,
                size: 18,
                color: isFolder ? const Color(0xFF4CAF50) : const Color(0xFF00BCD4),
              ),
              label: Text(
                file.name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onDeleted: () => _removeFile(index),
              backgroundColor: const Color(0xFF1E222A),
              side: BorderSide(color: Theme.of(context).dividerColor),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          VoiceButton(
            onTranscription: (text) {
              _messageController.text = text;
              _sendMessage();
            },
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showAttachMenu,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(
                Icons.attach_file,
                color: _attachedFiles.isNotEmpty ? const Color(0xFF00BCD4) : Colors.grey,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _attachedFiles.isNotEmpty ? 'Add a message...' : 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: chatState.isLoading
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
          _buildSendButton(chatState),
        ],
      ),
    );
  }

  Widget _buildSendButton(ChatState chatState) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: chatState.isLoading
            ? null
            : const LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
              ),
        color: chatState.isLoading ? const Color(0xFFE53935) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: chatState.isLoading
            ? [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
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
          onTap: chatState.isLoading
              ? () => ref.read(chatProvider.notifier).stopMessage()
              : _sendMessage,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              chatState.isLoading ? Icons.stop : Icons.send,
              color: Colors.white,
              size: 20,
            ),
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
