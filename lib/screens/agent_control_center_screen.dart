import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/services/multi_agent_orchestrator.dart';
import '../core/models/workflow.dart';
import '../core/agents/coding_agent.dart';
import '../core/agents/terminal_agent.dart';
import '../core/agents/git_agent.dart';
import '../core/services/debug_engine.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_tab_bar.dart';
import '../widgets/common/error_state.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/loading_overlay.dart';

class AgentControlCenterScreen extends ConsumerStatefulWidget {
  const AgentControlCenterScreen({super.key});

  @override
  ConsumerState<AgentControlCenterScreen> createState() => _AgentControlCenterScreenState();
}

class _AgentControlCenterScreenState extends ConsumerState<AgentControlCenterScreen> {
  int _selectedTab = 0;
  String? _selectedWorkflowId;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _listenToEvents();
  }

  void _listenToEvents() {
    ref.listen(orchestratorProvider, (previous, next) {
      if (next != null) {
        next.eventStream.listen((event) {
          setState(() {}); // Refresh UI on orchestrator events
        });
      }
    });
  }

  Future<void> _refreshWorkflows() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final orchestrator = ref.watch(orchestratorProvider);
    final codingAgent = ref.watch(codingAgentProvider);
    final terminalAgent = ref.watch(terminalAgentProvider);
    final gitAgent = ref.watch(gitAgentProvider);
    final debugEngine = ref.watch(debugEngineProvider);

    if (orchestrator == null) {
      return const Center(child: Text('Orchestrator not initialized'));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxxl, 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🤖 Agent Control Center',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Monitor and manage multi-agent workflows & coding jobs',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      GlassButton(
                        onPressed: _refreshWorkflows,
                        label: 'Refresh',
                        icon: Icons.refresh,
                        isCompact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            GlassTabBar(
              tabs: const [
                GlassTab(label: '🔄 Workflows'),
                GlassTab(label: '💻 Coding Jobs'),
              ],
              selectedIndex: _selectedTab,
              onTabChanged: (i) => setState(() => _selectedTab = i),
            ),

            const SizedBox(height: AppSpacing.xl),

            Expanded(
              child: _isRefreshing
                  ? const LoadingState(message: 'Updating...')
                  : _selectedTab == 0
                      ? _buildWorkflowList(orchestrator)
                      : _buildCodingJobs(codingAgent, terminalAgent, gitAgent, debugEngine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowList(MultiAgentOrchestrator orchestrator) {
    return FutureBuilder<List<Workflow>>(
      future: _getWorkflowsForTab(orchestrator),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: 'Failed to load workflows: ${snapshot.error}',
            onRetry: _refreshWorkflows,
            retryLabel: 'Retry',
          );
        }

        final workflows = snapshot.data ?? [];
        if (workflows.isEmpty) {
          return const EmptyState(
            icon: Icons.account_tree,
            title: 'No workflows found',
            subtitle: 'When you give a complex goal, JARVIS will\ncreate and track a workflow here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          itemCount: workflows.length,
          itemBuilder: (context, index) {
            final wf = workflows[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: GlassCard(
                child: InkWell(
                  onTap: () => setState(() => _selectedWorkflowId = wf.id),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _getWorkflowIcon(wf.status),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                wf.goal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              '${(wf.progress * 100).round()}%',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: wf.progress,
                          backgroundColor: AppColors.glassBorder,
                          color: _getStatusColor(wf.status),
                          minHeight: 4,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status: ${wf.status.name} | Tasks: ${wf.completedCount}/${wf.tasks.length}',
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            ),
                            if (wf.status == WorkflowStatus.running)
                              GlassButton(
                                onPressed: () => orchestrator.cancelWorkflow(wf.id),
                                label: 'Cancel',
                                icon: Icons.cancel,
                                isCompact: true,
                                variant: GlassButtonVariant.secondary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Workflow>> _getWorkflowsForTab(MultiAgentOrchestrator orchestrator) async {
    switch (_selectedTab) {
      case 0:
        return orchestrator.getActiveWorkflows();
      default:
        return orchestrator.getRecentWorkflows();
    }
  }

  Widget _buildCodingJobs(
    CodingAgent? codingAgent,
    TerminalAgent? terminalAgent,
    GitAgent? gitAgent,
    DebugEngine? debugEngine,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAgentStatusCard('💻 Coding Agent', codingAgent != null, 'Code generation, editing, refactoring', Icons.code),
          const SizedBox(height: AppSpacing.md),
          _buildAgentStatusCard('🐚 Terminal Agent', terminalAgent != null, 'Command execution, test running', Icons.terminal),
          const SizedBox(height: AppSpacing.md),
          _buildAgentStatusCard('🌿 Git Agent', gitAgent != null, 'Commit, push, branch management', Icons.source),
          const SizedBox(height: AppSpacing.md),
          _buildAgentStatusCard('🐛 Debug Engine', debugEngine != null, 'Stack trace parsing, autonomous patching', Icons.bug_report),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Recent Coding Jobs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          const EmptyState(
            icon: Icons.history,
            title: 'No coding jobs yet',
            subtitle: 'When you ask JARVIS to build, fix, or test code,\nthe jobs will appear here with live progress',
          ),
        ],
      ),
    );
  }

  Widget _buildAgentStatusCard(String name, bool active, String description, IconData icon) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? AppColors.accentGhost : AppColors.glassBorder,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: active ? AppColors.accent : AppColors.textTertiary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? Colors.green : AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(active ? 'Ready' : 'Unavailable', style: TextStyle(color: active ? Colors.green : AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _getWorkflowIcon(WorkflowStatus status) {
    switch (status) {
      case WorkflowStatus.completed: return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case WorkflowStatus.failed: return const Icon(Icons.error, color: Colors.red, size: 20);
      case WorkflowStatus.running: return const Icon(Icons.sync, color: AppColors.accent, size: 20);
      case WorkflowStatus.cancelled: return const Icon(Icons.cancel, color: Colors.grey, size: 20);
      default: return const Icon(Icons.hourglass_empty, color: Colors.amber, size: 20);
    }
  }

  Color _getStatusColor(WorkflowStatus status) {
    switch (status) {
      case WorkflowStatus.completed: return Colors.green;
      case WorkflowStatus.failed: return Colors.red;
      case WorkflowStatus.running: return AppColors.accent;
      default: return Colors.grey;
    }
  }
}
