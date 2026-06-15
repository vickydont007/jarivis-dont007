import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_provider.dart';
import '../../core/core.dart';
import '../../core/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/common/status_chip.dart';
import '../../widgets/orb/animated_orb.dart';

class AIControlCenter extends ConsumerStatefulWidget {
  const AIControlCenter({super.key});

  @override
  ConsumerState<AIControlCenter> createState() => _AIControlCenterState();
}

class _AIControlCenterState extends ConsumerState<AIControlCenter> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final agents = ref.watch(agentsStreamProvider).value ?? [];
    final activeAgents = agents.where((a) => a.isActive).length;

    return Container(
      color: AppColors.backgroundSecondary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User profile
            _buildProfile(appState),
            const SizedBox(height: 16),

            // AI Identity card
            _buildAIIdentity(appState),
            const SizedBox(height: 16),

            // Animated Orb
            _buildOrb(appState),
            const SizedBox(height: 16),

            // System status
            _buildSystemStatus(appState, activeAgents),
            const SizedBox(height: 16),

            // Quick actions
            _buildQuickActions(),
            const SizedBox(height: 16),

            // Agent activity
            _buildAgentActivity(agents),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(AppState appState) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accentGhost,
            child: const Icon(Icons.person, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('User', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(
                  appState.isConnected ? 'Connected' : 'Offline',
                  style: TextStyle(fontSize: 11, color: appState.isConnected ? AppColors.success : AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appState.isConnected ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIIdentity(AppState appState) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentGhost,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('💕', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Niya', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(
                      'Girlfriend AI',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              StatusChip(label: 'Online', status: ChipStatus.active),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(AppState appState) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('AI State', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedOrb(
              state: appState.isConnected ? OrbState.idle : OrbState.idle,
              size: 120,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appState.isConnected ? 'Ready' : 'Disconnected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: appState.isConnected ? AppColors.success : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus(AppState appState, int activeAgents) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.smart_toy, 'Active Agents', '$activeAgents', AppColors.success),
          _buildStatusRow(Icons.autorenew, 'Scheduler', appState.persistentScheduler != null ? 'Active' : 'Off',
            appState.persistentScheduler != null ? AppColors.success : AppColors.textTertiary),
          _buildStatusRow(Icons.memory, 'Memory', appState.memory != null ? 'Active' : 'Inactive',
            appState.memory != null ? AppColors.success : AppColors.textTertiary),
          _buildStatusRow(Icons.mic, 'Voice', appState.voiceService != null ? 'Ready' : 'Off',
            appState.voiceService != null ? AppColors.success : AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildAction(Icons.refresh, 'Refresh All', AppColors.accent),
          const SizedBox(height: 8),
          _buildAction(Icons.memory, 'Clear Memory', AppColors.warning),
          const SizedBox(height: 8),
          _buildAction(Icons.download, 'Export Data', AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Icon(Icons.chevron_right, size: 14, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentActivity(List agents) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agent Activity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (agents.isEmpty)
            const Text('No active agents', style: TextStyle(fontSize: 12, color: AppColors.textTertiary))
          else
            ...agents.take(5).map((agent) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: agent.isActive ? AppColors.success : AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      agent.name,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${agent.completedTasks}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
