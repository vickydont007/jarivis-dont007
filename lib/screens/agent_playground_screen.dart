import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/services/agent_executor.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/common/status_chip.dart';
import 'package:nextron_ai/providers/app_provider.dart';

class AgentPlaygroundScreen extends ConsumerStatefulWidget {
  const AgentPlaygroundScreen({super.key});

  @override
  ConsumerState<AgentPlaygroundScreen> createState() =>
      _AgentPlaygroundScreenState();
}

class _AgentPlaygroundScreenState extends ConsumerState<AgentPlaygroundScreen> {
  Agent? _selectedAgent;
  final TextEditingController _taskController = TextEditingController();
  final List<ExecutionStep> _steps = [];
  bool _isRunning = false;
  AgentTask? _currentTask;
  ExecutionResult? _lastResult;
  StreamSubscription? _agentSub;
  StreamSubscription? _stepSub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    _stepSub?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _runTask() async {
    if (_selectedAgent == null || _taskController.text.trim().isEmpty) return;
    if (_isRunning) return;

    final appState = ref.read(appStateProvider);
    final aiEngine = appState.aiEngine;
    final toolManager = appState.toolManager;

    if (aiEngine == null || toolManager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI not connected. Go to Settings to connect first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final agentManager = ref.read(agentManagerProvider);
    final timeline = ref.read(timelineServiceProvider);
    final orb = ref.read(orbStateManagerProvider);
    final taskDescription = _taskController.text.trim();

    setState(() {
      _isRunning = true;
      _currentTask = null;
      _steps.clear();
      _lastResult = null;
    });

    // Create real AgentExecutor
    final executor = AgentExecutor(
      aiEngine: aiEngine,
      toolManager: toolManager,
      timeline: timeline,
      orb: orb,
    );

    // Subscribe to execution steps
    _stepSub = executor.stepStream.listen((step) {
      if (mounted) {
        setState(() => _steps.insert(0, step));
      }
    });

    try {
      // Create task in AgentManager
      final task = await agentManager.startTask(
        agentId: _selectedAgent!.id,
        title: taskDescription,
        description: taskDescription,
      );
      _currentTask = task;

      // Subscribe to agent updates
      _agentSub = agentManager.agentUpdates.listen((agent) {
        if (agent.id == _selectedAgent!.id && mounted) {
          setState(() => _selectedAgent = agent);
        }
      });

      // Execute real task via AgentExecutor
      final result = await executor.execute(
        task: taskDescription,
        agentName: _selectedAgent!.name,
        systemPrompt: 'You are ${_selectedAgent!.name}. ${_selectedAgent!.description}. '
            'Execute the task using available tools. Be thorough and provide clear results.',
        maxIterations: 5,
      );

      _lastResult = result;

      // Complete or fail the task
      if (result.success) {
        await agentManager.completeTask(
          agentId: _selectedAgent!.id,
          taskId: task.id,
          result: result.response ?? 'Task completed',
        );
      } else {
        await agentManager.failTask(
          agentId: _selectedAgent!.id,
          taskId: task.id,
          error: result.error,
        );
      }
    } catch (e) {
      if (_currentTask != null) {
        await agentManager.failTask(
          agentId: _selectedAgent!.id,
          taskId: _currentTask!.id,
          error: e.toString(),
        );
      }
    } finally {
      _stepSub?.cancel();
      _agentSub?.cancel();
      executor.dispose();
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Left panel — Agent selector + controls
            SizedBox(
              width: 360,
              child: _buildLeftPanel(agents.value ?? []),
            ),
            // Divider
            const VerticalDivider(width: 1, color: AppColors.glassBorder),
            // Right panel — Real execution steps
            Expanded(
              child: _buildRightPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(List<dynamic> agentsList) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Agent Playground',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Real execution — no simulations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Agent selector
          const Text(
            'SELECT AGENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAgentDropdown(agentsList),

          const SizedBox(height: AppSpacing.xxl),

          // Selected agent info
          if (_selectedAgent != null) _buildAgentInfo(),

          const SizedBox(height: AppSpacing.xxl),

          // Task input
          const Text(
            'TASK DESCRIPTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlassTextField(
            controller: _taskController,
            hintText: 'e.g. Research today\'s AI news',
            maxLines: 3,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Run button
          GlassButton(
            label: _isRunning ? 'Executing...' : '▶ Run Real Task',
            variant: GlassButtonVariant.primary,
            onPressed: _isRunning ? null : _runTask,
            width: double.infinity,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Current task status
          if (_currentTask != null) _buildTaskStatus(),

          const Spacer(),

          // Last result summary
          if (_lastResult != null) _buildResultSummary(),
        ],
      ),
    );
  }

  Widget _buildAgentDropdown(List<dynamic> agentsList) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedAgent?.id,
          dropdownColor: AppColors.modalBackground,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          hint: const Text('Choose an agent...', style: TextStyle(color: AppColors.textTertiary)),
          items: agentsList.map<DropdownMenuItem<String>>((agent) {
            return DropdownMenuItem<String>(
              value: agent.id,
              child: Row(
                children: [
                  Text(agent.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(agent.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        Text(agent.description, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            final agent = agentsList.firstWhere((a) => a.id == id);
            setState(() => _selectedAgent = agent);
          },
        ),
      ),
    );
  }

  Widget _buildAgentInfo() {
    final agent = _selectedAgent!;
    final statusColor = agent.isActive
        ? AppColors.agentActive
        : agent.hasFailed
            ? AppColors.error
            : AppColors.agentIdle;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(agent.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(agent.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusChip(
                label: agent.status.name.toUpperCase(),
                status: agent.isActive ? ChipStatus.active : agent.hasFailed ? ChipStatus.error : ChipStatus.idle,
                isSmall: true,
              ),
              const SizedBox(width: AppSpacing.md),
              if (agent.currentTask != null)
                Expanded(
                  child: Text(
                    'Task: ${agent.currentTask}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (agent.progress > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: agent.progress,
                backgroundColor: AppColors.glassBorder,
                valueColor: AlwaysStoppedAnimation(statusColor),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskStatus() {
    final task = _currentTask!;
    return GlassCard(
      variant: GlassCardVariant.accent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline, size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              const Text('CURRENT TASK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.08, color: AppColors.textTertiary)),
              const Spacer(),
              StatusChip(
                label: task.status.name.toUpperCase(),
                status: task.isRunning ? ChipStatus.active : task.isDone ? ChipStatus.success : ChipStatus.error,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: AppColors.glassBorder,
              valueColor: AlwaysStoppedAnimation(task.isRunning ? AppColors.agentActive : AppColors.success),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary() {
    final result = _lastResult!;
    return GlassCard(
      variant: result.success ? GlassCardVariant.inline : GlassCardVariant.status,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                size: 14,
                color: result.success ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                result.success ? 'COMPLETED' : 'FAILED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: result.success ? AppColors.success : AppColors.error,
                ),
              ),
              const Spacer(),
              Text(
                '${result.duration.inSeconds}s',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textDisabled),
              ),
            ],
          ),
          if (result.response != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.response!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (result.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.glassBorder))),
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Execution Pipeline',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (_isRunning)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_steps.length} steps',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        // Steps list
        Expanded(
          child: _steps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, size: 32, color: AppColors.textDisabled),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Select an agent and run a task\nto see real execution steps',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return _buildStepCard(step);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepCard(ExecutionStep step) {
    final (color, icon) = _stepStyle(step.type);
    final time = '${step.timestamp.hour.toString().padLeft(2, '0')}:'
        '${step.timestamp.minute.toString().padLeft(2, '0')}:'
        '${step.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        variant: GlassCardVariant.inline,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.message,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: step.type == 'tool_call' || step.type == 'tool_result' ? 'monospace' : null,
                      color: color,
                    ),
                  ),
                  if (step.metadata != null && step.metadata!['args'] != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        step.metadata!['args'].toString(),
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textDisabled),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Time
            Text(
              time,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _stepStyle(String type) {
    switch (type) {
      case 'thinking':
        return (AppColors.accent, Icons.psychology);
      case 'tool_call':
        return (AppColors.warning, Icons.build);
      case 'tool_result':
        return (AppColors.success, Icons.check_circle_outline);
      case 'response':
        return (AppColors.success, Icons.output);
      case 'error':
        return (AppColors.error, Icons.error_outline);
      case 'info':
        return (AppColors.textTertiary, Icons.info_outline);
      default:
        return (AppColors.textTertiary, Icons.circle);
    }
  }
}
