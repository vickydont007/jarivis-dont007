import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/ai_engine.dart';
import '../core/capability_providers.dart';
import '../core/providers.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../services/voice_service.dart';
import '../widgets/orb/animated_orb.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/common/status_chip.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  bool _isListening = false;
  bool _isSending = false;
  bool _isSpeaking = false;
  VoiceMode _voiceMode = VoiceMode.idle;
  String _transcriptionText = '';
  String _voiceStatus = '';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Voice stream subscriptions
  StreamSubscription? _listeningSub;
  StreamSubscription? _transcriptionSub;
  StreamSubscription? _finalTranscriptionSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _ttsCompletionSub;
  StreamSubscription? _voiceModeSub;

  @override
  void initState() {
    super.initState();
    _setupVoiceStreams();
  }

  @override
  void dispose() {
    _cancelVoiceSubscriptions();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupVoiceStreams() {
    final appState = ref.read(appStateProvider);
    final voiceService = appState.voiceService;
    if (voiceService == null) return;

    _listeningSub = voiceService.listeningStream.listen((listening) {
      if (mounted) setState(() => _isListening = listening);
    });

    _transcriptionSub = voiceService.transcriptionStream.listen((text) {
      if (mounted) {
        setState(() => _transcriptionText = text);
        _messageController.text = text;
      }
    });

    _finalTranscriptionSub = voiceService.finalTranscriptionStream.listen((text) {
      if (mounted && text.isNotEmpty) {
        _messageController.text = text;
        setState(() => _transcriptionText = '');
        _sendMessage();
      }
    });

    _statusSub = voiceService.statusStream.listen((status) {
      if (mounted) setState(() => _voiceStatus = status);
    });

    _ttsCompletionSub = voiceService.ttsCompletionStream.listen((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _voiceModeSub = voiceService.voiceModeStream.listen((mode) {
      if (mounted) setState(() => _voiceMode = mode);
    });
  }

  void _cancelVoiceSubscriptions() {
    _listeningSub?.cancel();
    _transcriptionSub?.cancel();
    _finalTranscriptionSub?.cancel();
    _statusSub?.cancel();
    _ttsCompletionSub?.cancel();
    _voiceModeSub?.cancel();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    if (hour < 21) return '🌅';
    return '🌙';
  }

  void _handleOrbTap() {
    final voiceService = ref.read(appStateProvider).voiceService;
    if (voiceService == null || !voiceService.isSTTAvailable) return;

    if (_isListening) {
      voiceService.stopListening();
    } else {
      voiceService.resetSession();
      _messageController.clear();
      voiceService.startListening();
    }
  }

  void _toggleConversationMode() {
    final voiceService = ref.read(appStateProvider).voiceService;
    if (voiceService == null) return;

    if (_voiceMode == VoiceMode.listening || _voiceMode == VoiceMode.speaking) {
      voiceService.stopConversationMode();
    } else {
      _messageController.clear();
      voiceService.startConversationMode();
    }
  }

  void _sendMessage() async {
    if (_isSending) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _isSending = true;
    if (_isListening) {
      ref.read(appStateProvider).voiceService?.stopListening();
    }
    ref.read(chatProvider.notifier).addUserMessage(message);
    _messageController.clear();
    _scrollToBottom();

    final appState = ref.read(appStateProvider);

    if (appState.isConnected && appState.aiEngine != null) {
      try {
        final chatState = ref.read(chatProvider);
        final cancelToken = chatState.cancelToken;

        String response;
        if (AIEngine.isImageRequest(message)) {
          final result = await appState.aiEngine!.generateImage(message);
          response = result['success'] == true
              ? result['text'] ?? 'Here is the generated image.'
              : result['error'] ?? 'Failed to generate image.';
        } else {
          response = await ref.read(appStateProvider.notifier).sendMessage(
            message,
            history: chatState.messages
                .where((m) => m.role != 'system')
                .map((m) => {'role': m.role, 'content': m.content})
                .toList(),
            cancelToken: cancelToken,
          );
        }

        if (cancelToken != null && cancelToken.isCancelled) {
          _isSending = false;
          return;
        }

        ref.read(chatProvider.notifier).addAssistantMessage(response);
        _scrollToBottom();

        // Auto-speak response if voice is enabled
        final voiceService = appState.voiceService;
        if (voiceService != null && voiceService.autoSpeak && response.isNotEmpty) {
          final cleanResponse = voiceService.stripMarkdown(response);
          voiceService.speak(cleanResponse);
          setState(() => _isSpeaking = true);
        }
      } catch (e) {
        ref.read(chatProvider.notifier).addAssistantMessage('Error: $e');
      }
    } else {
      ref.read(chatProvider.notifier).addAssistantMessage(
          'Not connected. Please check your API key in Settings.');
    }

    _isSending = false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orbState = ref.watch(orbStateProvider);
    final briefing = ref.watch(briefingProvider);
    final memories = ref.watch(memoriesStreamProvider);
    final agents = ref.watch(agentsStreamProvider);
    final tasks = ref.watch(tasksProvider);
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildWelcomeView(orbState, briefing, memories, agents, tasks)
                  : _buildChatView(chatState),
            ),
            _buildInputBar(chatState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeView(
    AsyncValue<OrbState> orbState,
    AsyncValue<DailyBriefing?> briefing,
    AsyncValue<List> memories,
    AsyncValue<List> agents,
    AsyncValue<List> tasks,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.section),

          // The Orb
          Center(
            child: AnimatedOrb(
              state: orbState.value ?? OrbState.idle,
              size: AppSpacing.orbIdle,
              onTap: _handleOrbTap,
              label: _getOrbLabel(),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Transcription display
          if (_transcriptionText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Text(
                _transcriptionText,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.accent,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Greeting
          Text(
            '${_getGreeting()}, Vicky ${_getGreetingEmoji()}',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'How can I help you today?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Quick actions
          _buildQuickActions(),

          const SizedBox(height: AppSpacing.xxxl),

          // Briefing
          briefing.when(
            data: (b) => b != null
                ? _buildBriefingCard(b)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Status bar
          _buildStatusBar(
            memoryCount: memories.value?.length ?? 0,
            agentCount: agents.value?.length ?? 0,
            taskCount: tasks.value?.where((t) => !t.isCompleted).length ?? 0,
          ),
        ],
      ),
    );
  }

  String? _getOrbLabel() {
    if (_isListening) return 'I\'m listening...';
    if (_isSpeaking) return 'Speaking...';
    if (_voiceMode == VoiceMode.processing) return 'Processing...';
    if (_voiceMode == VoiceMode.listening) return 'Listening...';
    if (_voiceMode == VoiceMode.speaking) return 'Speaking...';
    return null;
  }

  Widget _buildChatView(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        final msg = chatState.messages[index];
        final isUser = msg.role == 'user';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentMuted],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('◉',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.glassFill,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: isUser
                          ? AppColors.accent.withOpacity(0.2)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isUser
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Center(
                    child: Text('V',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildQuickAction(Icons.chat_bubble_outline, 'Chat', () {}),
        const SizedBox(width: AppSpacing.lg),
        _buildQuickAction(Icons.alarm_add_outlined, 'Schedule', () {}),
        const SizedBox(width: AppSpacing.lg),
        _buildQuickAction(Icons.search, 'Search', () {}),
        const SizedBox(width: AppSpacing.lg),
        _buildQuickAction(Icons.photo_camera_outlined, 'Analyze', () {}),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingCard(DailyBriefing briefing) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                briefing.greeting.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (briefing.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                briefing.summary,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ...briefing.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildSuggestionItem(
                  _iconForBriefingType(item.type),
                  item.title,
                  item.description,
                ),
              )),
          if (briefing.items.isEmpty)
            const Text(
              'No recent activity. Start a conversation!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForBriefingType(BriefingItemType type) {
    switch (type) {
      case BriefingItemType.memoryUpdate: return Icons.psychology_outlined;
      case BriefingItemType.agentActivity: return Icons.smart_toy_outlined;
      case BriefingItemType.automationEvent: return Icons.autorenew;
      case BriefingItemType.calendarEvent: return Icons.task_outlined;
      case BriefingItemType.systemEvent: return Icons.computer;
    }
  }

  Widget _buildSuggestionItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar({
    required int memoryCount,
    required int agentCount,
    required int taskCount,
  }) {
    return GlassCard(
      variant: GlassCardVariant.inline,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatusBarItem(
            icon: Icons.psychology_outlined,
            label: '$memoryCount',
            sublabel: 'memories',
          ),
          _StatusBarItem(
            icon: Icons.alarm_outlined,
            label: '$taskCount',
            sublabel: 'active tasks',
          ),
          _StatusBarItem(
            icon: Icons.smart_toy_outlined,
            label: '$agentCount',
            sublabel: 'agents',
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar([bool isLoading = false]) {
    final voiceService = ref.read(appStateProvider).voiceService;
    final hasVoice = voiceService != null && voiceService.isSTTAvailable;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Voice button
            if (hasVoice)
              GestureDetector(
                onTap: _handleOrbTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.glassFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    size: 18,
                    color: _isListening ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
            if (hasVoice) const SizedBox(width: AppSpacing.sm),
            // Conversation mode button
            if (hasVoice)
              GestureDetector(
                onTap: _toggleConversationMode,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _voiceMode == VoiceMode.listening ||
                            _voiceMode == VoiceMode.speaking
                        ? Colors.green.withOpacity(0.15)
                        : AppColors.glassFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.record_voice_over,
                    size: 18,
                    color: _voiceMode == VoiceMode.listening ||
                            _voiceMode == VoiceMode.speaking
                        ? Colors.green
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            if (hasVoice) const SizedBox(width: AppSpacing.md),
            // Text input
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? 'Listening...'
                      : _voiceStatus.isNotEmpty
                          ? _voiceStatus
                          : 'Type a message or tap the mic...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            // Send button
            GestureDetector(
              onTap: isLoading ? null : _sendMessage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLoading ? AppColors.textDisabled : AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _StatusBarItem({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          sublabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
