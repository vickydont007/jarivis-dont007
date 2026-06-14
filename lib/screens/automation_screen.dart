import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/capability_providers.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_tab_bar.dart';
import '../widgets/common/status_chip.dart';

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(activityTimelineProvider);
    final agents = ref.watch(agentsStreamProvider);
    final agentManager = ref.watch(agentManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚙️ Automations',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Things your AI does for you automatically',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              GlassTabBar(
                tabs: const [
                  GlassTab(label: 'Timeline'),
                  GlassTab(label: 'Tool Stats'),
                  GlassTab(label: 'Stats'),
                ],
                selectedIndex: _selectedTab,
                onTabChanged: (i) => setState(() => _selectedTab = i),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Tab content
              if (_selectedTab == 0)
                _buildTimelineTab(timeline.value ?? []),
              if (_selectedTab == 1)
                _buildToolStatsTab(agentManager),
              if (_selectedTab == 2)
                _buildStatsTab(
                  agents: agents.value ?? [],
                  events: timeline.value ?? [],
                  agentManager: agentManager,
                ),

              const SizedBox(height: AppSpacing.xxl),

              GlassButton(
                label: '✨ Create New Automation',
                variant: GlassButtonVariant.secondary,
                onPressed: () {},
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineTab(dynamic eventsData) {
    final events = eventsData is List ? eventsData.cast<ActivityEvent>() : <ActivityEvent>[];
    if (events.isEmpty) {
      return GlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              'No activity yet. Start using your AI!',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...events.take(10).map((event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _buildEventCard(event),
            )),
      ],
    );
  }

  Widget _buildEventCard(ActivityEvent event) {
    return GlassCard(
      variant: GlassCardVariant.inline,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _colorForEventType(event.type).withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              _iconForEventType(event.type),
              size: 18,
              color: _colorForEventType(event.type),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.source} • ${_timeAgo(event.timestamp)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolStatsTab(AgentManager agentManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AGENT PERFORMANCE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          child: FutureBuilder(
            future: agentManager.getAllAgents(),
            builder: (context, snapshot) {
              final agents = snapshot.data ?? [];
              final totalTasks = agents.fold(0, (sum, a) => sum + a.totalTasks);
              final completedTasks = agents.fold(0, (sum, a) => sum + a.completedTasks);
              final failedTasks = agents.fold(0, (sum, a) => sum + a.failedTasks);
              return Column(
                children: [
                  _buildStatRow('Registered Agents', '${agents.length}'),
                  const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
                  _buildStatRow('Total Tasks Executed', '$totalTasks'),
                  const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
                  _buildStatRow('Successful', '$completedTasks'),
                  const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
                  _buildStatRow('Failed', '$failedTasks'),
                  const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
                  _buildStatRow('Success Rate', totalTasks > 0
                      ? '${((completedTasks / totalTasks) * 100).toStringAsFixed(0)}%'
                      : 'N/A'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab({
    required dynamic agents,
    required dynamic events,
    required AgentManager agentManager,
  }) {
    final agentList = agents is List ? agents.cast<Agent>() : <Agent>[];
    final eventList = events is List ? events.cast<ActivityEvent>() : <ActivityEvent>[];
    final memoryEvents = eventList.where((e) => e.type == ActivityType.memoryCreated).length;
    final agentEvents = eventList.where((e) =>
        e.type == ActivityType.agentStarted || e.type == ActivityType.agentCompleted).length;
    final totalTasks = agentList.fold(0, (sum, a) => sum + a.totalTasks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SYSTEM OVERVIEW',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          child: Column(
            children: [
              _buildStatRow('Active Agents', '${agentList.where((a) => a.isActive).length}/${agentList.length}'),
              const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
              _buildStatRow('Total Events', '${eventList.length}'),
              const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
              _buildStatRow('Memories Created', '$memoryEvents'),
              const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
              _buildStatRow('Agent Activities', '$agentEvents'),
              const Divider(color: AppColors.glassBorder, height: AppSpacing.lg),
              _buildStatRow('Tools Executed', '$totalTasks'),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForEventType(ActivityType type) {
    switch (type) {
      case ActivityType.memoryCreated: return Icons.psychology_outlined;
      case ActivityType.agentStarted: return Icons.play_arrow;
      case ActivityType.agentCompleted: return Icons.check_circle_outline;
      case ActivityType.agentFailed: return Icons.error_outline;
      case ActivityType.automationExecuted: return Icons.autorenew;
      case ActivityType.desktopActionExecuted: return Icons.computer;
      case ActivityType.voiceSessionStarted: return Icons.mic;
      case ActivityType.systemEvent: return Icons.build;
      default: return Icons.circle;
    }
  }

  Color _colorForEventType(ActivityType type) {
    switch (type) {
      case ActivityType.memoryCreated: return AppColors.accent;
      case ActivityType.agentStarted: return AppColors.agentActive;
      case ActivityType.agentCompleted: return AppColors.success;
      case ActivityType.agentFailed: return AppColors.error;
      case ActivityType.automationExecuted: return AppColors.warning;
      case ActivityType.systemEvent: return AppColors.info;
      default: return AppColors.textTertiary;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
