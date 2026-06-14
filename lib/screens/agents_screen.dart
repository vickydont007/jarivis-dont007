import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/common/status_chip.dart';

class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsStreamProvider);

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
                '🤖 Your AI Team',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Agents working for you',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Agent cards — real data from AgentManager
              agents.when(
                data: (agentList) {
                  if (agentList.isEmpty) {
                    return GlassCard(
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            'No agents yet. Spawn one to get started!',
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
                    children: agentList.map((agent) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _buildAgentCard(
                        agent: agent,
                      ),
                    )).toList(),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => GlassCard(
                  child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: '+ Spawn Agent',
                      icon: Icons.add,
                      variant: GlassButtonVariant.secondary,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: GlassButton(
                      label: 'Force Layout',
                      icon: Icons.grid_view,
                      variant: GlassButtonVariant.secondary,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCard({required Agent agent}) {
    final statusColor = agent.isActive
        ? AppColors.agentActive
        : agent.hasFailed
            ? AppColors.error
            : AppColors.agentIdle;

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              _iconForAgentType(agent.name),
              size: 24,
              color: statusColor,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        agent.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    StatusChip(
                      label: agent.status.name,
                      status: agent.isActive
                          ? ChipStatus.active
                          : ChipStatus.idle,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  agent.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: agent.progress,
                    backgroundColor: AppColors.glassBorder,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tasks: ${agent.completedTasks} completed, ${agent.failedTasks} failed',
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

  IconData _iconForAgentType(String type) {
    switch (type) {
      case 'research': return Icons.science_outlined;
      case 'coding': return Icons.code_outlined;
      case 'planner': return Icons.task_outlined;
      case 'automation': return Icons.autorenew;
      case 'monitor': return Icons.language_outlined;
      default: return Icons.smart_toy_outlined;
    }
  }
}
