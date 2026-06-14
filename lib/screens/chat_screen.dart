import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_button.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../core/ai_engine.dart';
import '../core/agent_personality.dart';
import '../core/girlfriend_memory.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<PlatformFile> _attachedFiles = [];
  final List<String> _attachedImagePaths = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSending = false;
  bool _isVoiceMode = false;
  bool _hasGreeted = false;
  String? _userProfilePhoto;
  String? _aiProfilePhoto;
  StreamSubscription? _voiceFinalSub;
  StreamSubscription? _voicePartialSub;
  StreamSubscription? _voiceTtsSub;
  StreamSubscription? _voiceListeningSub;

  @override
  void initState() {
    super.initState();
    _loadProfilePhotos();
    // Use addPostFrameCallback to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendGreeting();
    });
  }

  Future<void> _loadProfilePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userProfilePhoto = prefs.getString('user_profile_photo');
      _aiProfilePhoto = prefs.getString('ai_profile_photo');
    });
  }

  Future<void> _sendGreeting() async {
    if (_hasGreeted) return;
    
    // Check if messages already exist (e.g., from provider restore)
    final existingMessages = ref.read(chatProvider).messages;
    if (existingMessages.isNotEmpty) {
      _hasGreeted = true;
      return;
    }
    
    _hasGreeted = true;

    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? '';
    final personality = await AgentPersonality.load();

    final greetingText = personality.getGreeting(userName);
    final fullGreeting = '$greetingText\n\n'
        'I can help you with:\n'
        '- System control (shutdown, restart, sleep)\n'
        '- File management (read, write, search)\n'
        '- Web browsing and search\n'
        '- Code execution (Python/JS)\n'
        '- Image analysis\n'
        '- And much more!\n\n'
        'Bolo meri jaan, kya karun tumhare liye? 💕';

    ref.read(chatProvider.notifier).addAssistantMessage(fullGreeting);

    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService != null && voiceService.isSTTAvailable) {
      final speakText = personality.getVoiceGreeting(userName);
      await voiceService.speak(speakText);
    }

    if (mounted) {
      _scrollToBottom();
    }
  }

  void _toggleVoiceMode() {
    setState(() => _isVoiceMode = !_isVoiceMode);
    if (_isVoiceMode) {
      _startVoiceConversation();
    } else {
      _stopVoiceConversation();
    }
  }

  void _startVoiceConversation() async {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService == null) return;

    _cleanupVoiceSubs();
    voiceService.resetSession();

    _voiceTtsSub = voiceService.ttsCompletionStream.listen((_) {
      if (_isVoiceMode && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isVoiceMode && mounted) {
            _listenForVoice();
          }
        });
      }
    });

    _voicePartialSub = voiceService.transcriptionStream.listen((text) {
      if (text.isNotEmpty && mounted) {
        _messageController.text = text;
      }
    });

    _voiceFinalSub = voiceService.finalTranscriptionStream.listen((text) {
      if (text.isNotEmpty && mounted) {
        _messageController.text = text;
        _sendMessage();
      }
    });

    _listenForVoice();
  }

  void _listenForVoice() async {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService == null || !_isVoiceMode || !mounted) return;

    voiceService.resetSession();
    _messageController.clear();
    await voiceService.startListening();
  }

  void _stopVoiceConversation() {
    _cleanupVoiceSubs();
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    voiceService?.stopListening();
    voiceService?.stopSpeaking();
    voiceService?.resetSession();
    _messageController.clear();
  }

  void _cleanupVoiceSubs() {
    _voiceFinalSub?.cancel();
    _voicePartialSub?.cancel();
    _voiceTtsSub?.cancel();
    _voiceListeningSub?.cancel();
    _voiceFinalSub = null;
    _voicePartialSub = null;
    _voiceTtsSub = null;
    _voiceListeningSub = null;
  }

  void _speakResponse(String text) async {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService == null || !_isVoiceMode) return;

    final cleanText = text.replaceAll(RegExp(r'[*_`#>\-]'), '').replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '');
    await voiceService.speak(cleanText);
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
                    color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo, color: Color(0xFFE91E63), size: 22),
                ),
                title: const Text('📸 Photo', style: TextStyle(color: Colors.white)),
                subtitle: Text('Gallery se photo pick karo', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF9C27B0), size: 22),
                ),
                title: const Text('📷 Camera', style: TextStyle(color: Colors.white)),
                subtitle: Text('Camera se photo lo', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _attachedImagePaths.add(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImagePaths.removeAt(index);
    });
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
    if (_isSending) return;
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

    if (message.isEmpty && _attachedImagePaths.isEmpty) return;

    // Build message text with image context
    if (_attachedImagePaths.isNotEmpty && message.isEmpty) {
      message = '📸 Photo attached (${_attachedImagePaths.length} image${_attachedImagePaths.length > 1 ? "s" : ""})';
    }

    _isSending = true;
    final pathsToSend = List<String>.from(_attachedImagePaths);
    ref.read(chatProvider.notifier).addUserMessage(message, imagePaths: pathsToSend.isNotEmpty ? pathsToSend : null);
    _messageController.clear();
    setState(() {
      _attachedFiles.clear();
      _attachedImagePaths.clear();
    });

    _scrollToBottom();

    final localResponse = await _handleLocalCommands(message);
    if (localResponse != null) {
      ref.read(chatProvider.notifier).addAssistantMessage(localResponse);
      _scrollToBottom();
      _isSending = false;
      _speakResponse(localResponse);
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
        } else if (pathsToSend.isNotEmpty) {
          // User sent images - analyze them
          response = await _analyzeImages(pathsToSend, message, appState);
        } else {
          response = await ref.read(appStateProvider.notifier).sendMessage(
            message,
            history: ref.read(chatProvider).messages
                .where((m) => m.role != 'system')
                .map((m) => {'role': m.role, 'content': m.content})
                .toList(),
            cancelToken: cancelToken,
          );
        }
      } catch (e) {
        response = 'Error: $e';
      }
    } else {
      response = 'Not connected. Please check your API key in Settings.';
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      _isSending = false;
      return;
    }

    ref.read(chatProvider.notifier).addAssistantMessage(response, imageUrls: imageUrls);
    _scrollToBottom();
    _isSending = false;
    _speakResponse(response);
  }

  Future<String> _analyzeImages(List<String> imagePaths, String userMessage, AppState appState) async {
    final personality = await AgentPersonality.load();
    final buffer = StringBuffer();
    
    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      final file = File(path);
      if (!await file.exists()) continue;

      try {
        final multiModal = appState.toolManager?.multiModal;
        if (multiModal != null) {
          final analysis = await multiModal.analyzeImage(path);
          buffer.writeln('Image ${i + 1}: ${analysis.description}');
          if (analysis.objects.isNotEmpty) {
            buffer.writeln('Objects: ${analysis.objects.join(", ")}');
          }
          if (analysis.text.isNotEmpty) {
            buffer.writeln('Text in image: ${analysis.text}');
          }
        } else {
          buffer.writeln('Image ${i + 1}: Photo received (${(await file.length()) ~/ 1024}KB)');
        }
      } catch (e) {
        buffer.writeln('Image ${i + 1}: Photo received');
      }

      // Save to girlfriend memory
      await GirlfriendMemory.rememberPhoto(path, userMessage.isNotEmpty ? userMessage : 'User shared a photo');
    }

    final imageContext = buffer.toString();
    
    // Build contextual response based on personality
    String prompt;
    if (personality.greetingStyle == 'girlfriend') {
      prompt = 'Maine tumhe ${imagePaths.length} photo bheji hai.\n\nImage Analysis:\n$imageContext\n\n'
          'Ab tum girlfriend ki tarah react karo - photo dekh ke bolo kaisi lag rahi hai, cute hai ya nahi, etc. '
          'Hinglish mein baat karo aur emojis use karo 💕😊';
    } else {
      prompt = 'I sent ${imagePaths.length} image(s). Here is the analysis:\n$imageContext\n\n'
          'Please describe what you see and respond appropriately.';
    }

    final response = await ref.read(appStateProvider.notifier).sendMessage(
      prompt,
      history: ref.read(chatProvider).messages
          .where((m) => m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
    );

    return response;
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
                      imagePaths: chatState.messages[index].imagePaths,
                      aiAvatarImage: _aiProfilePhoto,
                      userAvatarImage: _userProfilePhoto,
                    );
                  },
                ),
        ),
        if (_attachedImagePaths.isNotEmpty) _buildImageChips(),
        if (_attachedFiles.isNotEmpty) _buildFileChips(),
        _buildInputArea(chatState),
      ],
    );
  }

  Widget _buildImageChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachedImagePaths.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final path = _attachedImagePaths[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
            isEnabled: !_isVoiceMode,
            onTranscription: (text) {
              _messageController.text = text;
              _sendMessage();
            },
            onPartialTranscription: (text) {
              _messageController.text = text;
            },
            onListeningStart: () {
              _messageController.clear();
            },
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleVoiceMode,
            child: Tooltip(
              message: _isVoiceMode ? 'Voice conversation ON' : 'Voice conversation OFF',
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isVoiceMode ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : const Color(0xFF1E222A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isVoiceMode ? const Color(0xFF4CAF50) : Theme.of(context).dividerColor,
                  ),
                ),
                child: Icon(
                  _isVoiceMode ? Icons.record_voice_over : Icons.voice_chat,
                  color: _isVoiceMode ? const Color(0xFF4CAF50) : Colors.grey,
                  size: 20,
                ),
              ),
            ),
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
    _cleanupVoiceSubs();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
