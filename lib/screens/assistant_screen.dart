import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/capability_providers.dart';
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
  final TextEditingController _messageController = TextEditingController();

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
    setState(() => _isListening = !_isListening);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final orbState = ref.watch(orbStateProvider);
    final briefing = ref.watch(briefingProvider);
    final memories = ref.watch(memoriesStreamProvider);
    final agents = ref.watch(agentsStreamProvider);
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.section),

                    // The Orb — real state from OrbStateManager
                    Center(
                      child: AnimatedOrb(
                        state: orbState.value ?? OrbState.idle,
                        size: AppSpacing.orbIdle,
                        onTap: _handleOrbTap,
                        label: _isListening
                            ? 'I\'m listening...'
                            : (orbState.value == OrbState.thinking)
                                ? 'Let me think...'
                                : (orbState.value == OrbState.speaking)
                                    ? 'Speaking...'
                                    : null,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

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

                    // Briefing from BriefingService
                    briefing.when(
                      data: (b) => b != null
                          ? _buildBriefingCard(b)
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Status bar — real data
                    _buildStatusBar(
                      memoryCount: memories.value?.length ?? 0,
                      agentCount: agents.value?.length ?? 0,
                      taskCount: tasks.value?.where((t) => !t.isCompleted).length ?? 0,
                    ),
                  ],
                ),
              ),
            ),

            // Input bar
            _buildInputBar(),
          ],
        ),
      ),
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

  Widget _buildInputBar() {
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
            const SizedBox(width: AppSpacing.md),
            // Text input
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message or tap the orb...',
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
              onTap: _sendMessage,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
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
