import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/capability_providers.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/common/status_chip.dart';

class AgentPlaygroundScreen extends ConsumerStatefulWidget {
  const AgentPlaygroundScreen({super.key});

  @override
  ConsumerState<AgentPlaygroundScreen> createState() =>
      _AgentPlaygroundScreenState();
}

class _AgentPlaygroundScreenState extends ConsumerState<AgentPlaygroundScreen> {
  Agent? _selectedAgent;
  final TextEditingController _taskController = TextEditingController();
  final List<LogEntry> _logs = [];
  final List<ToolCall> _toolCalls = [];
  bool _isRunning = false;
  AgentTask? _currentTask;
  StreamSubscription? _agentSub;
  StreamSubscription? _taskSub;

  @override
  void initState() {
    super.initState();
    _addLog('info', 'Playground initialized');
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    _taskSub?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  void _addLog(String level, String message) {
    setState(() {
      _logs.insert(
        0,
        LogEntry(
          timestamp: DateTime.now(),
          level: level,
          message: message,
        ),
      );
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  void _addToolCall(String name, String params, String result, int durationMs) {
    setState(() {
      _toolCalls.insert(
        0,
        ToolCall(
          timestamp: DateTime.now(),
          name: name,
          params: params,
          result: result,
          durationMs: durationMs,
        ),
      );
    });
  }

  Future<void> _runTask() async {
    if (_selectedAgent == null || _taskController.text.trim().isEmpty) return;
    if (_isRunning) return;

    final agentManager = ref.read(agentManagerProvider);
    final timeline = ref.read(timelineServiceProvider);
    final taskDescription = _taskController.text.trim();

    setState(() {
      _isRunning = true;
      _currentTask = null;
      _toolCalls.clear();
      _logs.clear();
    });

    _addLog('info', '━━━ Task Execution Started ━━━');
    _addLog('input', 'Agent: ${_selectedAgent!.name}');
    _addLog('input', 'Task: "$taskDescription"');

    try {
      // Step 1: Create task
      _addLog('step', 'Creating task...');
      final task = await agentManager.startTask(
        agentId: _selectedAgent!.id,
        title: taskDescription,
        description: taskDescription,
      );
      _currentTask = task;
      _addLog('ok', 'Task created: ${task.id.substring(0, 8)}...');

      // Step 2: Subscribe to updates
      _agentSub = agentManager.agentUpdates.listen((agent) {
        if (agent.id == _selectedAgent!.id) {
          setState(() => _selectedAgent = agent);
        }
      });
      _taskSub = agentManager.taskUpdates.listen((t) {
        if (t.id == task.id) {
          _currentTask = t;
        }
      });

      // Step 3: Simulate analysis phase
      _addLog('step', 'Analyzing task requirements...');
      await _simulateProgress(agentManager, task, 0.1, 'analysis');
      _addToolCall(
        'analyze_task',
        '{"task": "$taskDescription"}',
        '{"phase": "analysis", "complexity": "moderate"}',
        245,
      );
      _addLog('ok', 'Analysis complete');

      // Step 4: Simulate research phase
      _addLog('step', 'Researching information...');
      await _simulateProgress(agentManager, task, 0.3, 'research');
      _addToolCall(
        'search_knowledge',
        '{"query": "$taskDescription"}',
        '{"results": 5, "relevance": 0.92}',
        890,
      );
      _addLog('ok', 'Research complete — 5 sources found');

      // Step 5: Simulate tool usage
      _addLog('step', 'Executing tools...');
      await _simulateProgress(agentManager, task, 0.5, 'tool_execution');

      // Simulate different tools based on agent type
      final tools = _getToolsForAgent(_selectedAgent!.name);
      for (final tool in tools) {
        await Future.delayed(const Duration(milliseconds: 300));
        final duration = 100 + (DateTime.now().microsecond % 500);
        _addToolCall(
          tool['name']!,
          tool['params']!,
          tool['result']!,
          duration,
        );
        _addLog('tool', 'Tool: ${tool["name"]} (${duration}ms)');
      }

      // Step 6: Simulate processing
      _addLog('step', 'Processing results...');
      await _simulateProgress(agentManager, task, 0.7, 'processing');
      _addToolCall(
        'process_results',
        '{"mode": "synthesis"}',
        '{"insights": 3, "confidence": 0.88}',
        456,
      );
      _addLog('ok', 'Processing complete');

      // Step 7: Generate output
      _addLog('step', 'Generating output...');
      await _simulateProgress(agentManager, task, 0.9, 'generation');
      _addToolCall(
        'generate_response',
        '{"format": "structured"}',
        '{"tokens": 847, "quality": "high"}',
        678,
      );

      // Step 8: Complete
      await _simulateProgress(agentManager, task, 1.0, 'completion');
      final result = _generateResult(taskDescription);
      await agentManager.completeTask(
        agentId: _selectedAgent!.id,
        taskId: task.id,
        result: result,
      );

      _addLog('ok', '━━━ Task Completed Successfully ━━━');
      _addLog('result', 'Result: $result');

      // Log to timeline
      await timeline.log(
        source: 'Playground',
        type: ActivityType.automationExecuted,
        title: 'Playground Task Completed',
        description: '${_selectedAgent!.name}: $taskDescription',
        metadata: {
          'agentId': _selectedAgent!.id,
          'taskId': task.id,
          'toolCalls': _toolCalls.length,
        },
      );
    } catch (e) {
      _addLog('error', 'Task failed: $e');
      if (_currentTask != null) {
        await agentManager.failTask(
          agentId: _selectedAgent!.id,
          taskId: _currentTask!.id,
          error: e.toString(),
        );
      }
    } finally {
      _agentSub?.cancel();
      _taskSub?.cancel();
      setState(() => _isRunning = false);
    }
  }

  Future<void> _simulateProgress(
    AgentManager manager,
    AgentTask task,
    double progress,
    String phase,
  ) async {
    await manager.updateProgress(
      agentId: _selectedAgent!.id,
      taskId: task.id,
      progress: progress,
    );
    _addLog('progress', '${(progress * 100).round()}% — $phase');
    await Future.delayed(const Duration(milliseconds: 400));
  }

  List<Map<String, String>> _getToolsForAgent(String agentName) {
    switch (agentName) {
      case 'Research Agent':
        return [
          {
            'name': 'web_search',
            'params': '{"query": "latest AI news"}',
            'result': '{"url": "https://...", "title": "AI Breakthroughs 2026"}',
          },
          {
            'name': 'extract_content',
            'params': '{"url": "https://..."}',
            'result': '{"words": 2400, "keyPoints": 5}',
          },
        ];
      case 'Coding Agent':
        return [
          {
            'name': 'read_file',
            'params': '{"path": "lib/main.dart"}',
            'result': '{"lines": 142, "language": "dart"}',
          },
          {
            'name': 'analyze_code',
            'params': '{"file": "main.dart"}',
            'result': '{"complexity": "low", "issues": 0}',
          },
        ];
      case 'Planner Agent':
        return [
          {
            'name': 'get_calendar',
            'params': '{"date": "today"}',
            'result': '{"events": 3, "next": "Team standup"}',
          },
          {
            'name': 'create_task',
            'params': '{"title": "Follow up"}',
            'result': '{"taskId": "tsk_abc123", "status": "created"}',
          },
        ];
      case 'Automation Agent':
        return [
          {
            'name': 'list_automations',
            'params': '{}',
            'result': '{"active": 5, "total": 12}',
          },
          {
            'name': 'execute_workflow',
            'params': '{"workflow": "daily_report"}',
            'result': '{"status": "running", "steps": 4}',
          },
        ];
      case 'Monitor Agent':
        return [
          {
            'name': 'system_metrics',
            'params': '{}',
            'result': '{"cpu": "23%", "memory": "67%", "disk": "45%"}',
          },
          {
            'name': 'check_services',
            'params': '{}',
            'result': '{"online": 8, "offline": 0}',
          },
        ];
      default:
        return [
          {
            'name': 'generic_tool',
            'params': '{}',
            'result': '{"status": "ok"}',
          },
        ];
    }
  }

  String _generateResult(String taskDescription) {
    return 'Task "$taskDescription" completed. '
        'Analyzed ${_toolCalls.length} tool calls, '
        'generated insights with high confidence. '
        'All sub-tasks finished successfully.';
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsStreamProvider);
    final timeline = ref.watch(activityStreamProvider);

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
            // Right panel — Logs, tool calls, timeline
            Expanded(
              child: _buildRightPanel(timeline.value ?? []),
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
            'Test and validate agent execution',
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
            hintText: 'Enter a task for the agent...',
            maxLines: 3,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Run button
          GlassButton(
            label: _isRunning ? 'Running...' : '▶ Run Task',
            variant: GlassButtonVariant.primary,
            onPressed: _isRunning ? null : _runTask,
            width: double.infinity,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Current task status
          if (_currentTask != null) _buildTaskStatus(),

          const Spacer(),

          // Stats footer
          _buildStatsFooter(),
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
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          hint: const Text(
            'Choose an agent...',
            style: TextStyle(color: AppColors.textTertiary),
          ),
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
                        Text(
                          agent.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          agent.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
            _addLog('info', 'Selected agent: ${agent.name}');
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
                    Text(
                      agent.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      agent.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
                status: agent.isActive
                    ? ChipStatus.active
                    : agent.hasFailed
                        ? ChipStatus.error
                        : ChipStatus.idle,
                isSmall: true,
              ),
              const SizedBox(width: AppSpacing.md),
              if (agent.currentTask != null)
                Expanded(
                  child: Text(
                    'Task: ${agent.currentTask}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
            const SizedBox(height: 4),
            Text(
              '${(agent.progress * 100).round()}% complete',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildMiniStat('Total', '${agent.totalTasks}'),
              const SizedBox(width: AppSpacing.md),
              _buildMiniStat('Done', '${agent.completedTasks}'),
              const SizedBox(width: AppSpacing.md),
              _buildMiniStat('Failed', '${agent.failedTasks}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskStatus() {
    final task = _currentTask!;
    final statusColor = task.isRunning
        ? AppColors.agentActive
        : task.isDone
            ? AppColors.success
            : task.hasFailed
                ? AppColors.error
                : AppColors.textTertiary;

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
              const Text(
                'CURRENT TASK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08,
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              StatusChip(
                label: task.status.name.toUpperCase(),
                status: task.isRunning
                    ? ChipStatus.active
                    : task.isDone
                        ? ChipStatus.success
                        : ChipStatus.error,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (task.result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                task.result!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (task.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                task.error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: AppColors.glassBorder,
              valueColor: AlwaysStoppedAnimation(statusColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsFooter() {
    return GlassCard(
      variant: GlassCardVariant.inline,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFooterStat(Icons.build, '${_toolCalls.length}', 'tools'),
          _buildFooterStat(Icons.list_alt, '${_logs.length}', 'logs'),
          if (_currentTask != null)
            _buildFooterStat(
              Icons.timer,
              _currentTask!.duration != null
                  ? '${_currentTask!.duration!.inSeconds}s'
                  : '—',
              'duration',
            ),
        ],
      ),
    );
  }

  Widget _buildFooterStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          '$value ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(dynamic eventsData) {
    final events = eventsData is List ? eventsData : <dynamic>[];
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Tab bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.glassBorder),
              ),
            ),
            child: Row(
              children: [
                _buildTab('Tool Calls', _toolCalls.length),
                const SizedBox(width: AppSpacing.xl),
                _buildTab('Execution Log', _logs.length),
                const SizedBox(width: AppSpacing.xl),
                _buildTab('Timeline', events.length),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildToolCallsPanel(),
                _buildLogsPanel(),
                _buildTimelinePanel(events),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCallsPanel() {
    if (_toolCalls.isEmpty) {
      return const Center(
        child: Text(
          'No tool calls yet.\nRun a task to see tool executions.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _toolCalls.length,
      itemBuilder: (context, index) {
        final call = _toolCalls[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildToolCallCard(call),
        );
      },
    );
  }

  Widget _buildToolCallCard(ToolCall call) {
    return GlassCard(
      variant: GlassCardVariant.inline,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, size: 14, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                call.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.agentActive.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${call.durationMs}ms',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.agentActive,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildCodeBlock('Params', call.params),
          const SizedBox(height: AppSpacing.xs),
          _buildCodeBlock('Result', call.result),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String label, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text(
          'No execution logs yet.\nRun a task to see logs.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogEntry(log);
      },
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    final (color, icon) = _logStyle(log.level);
    final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}.'
        '${log.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Icon
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.sm),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              log.level.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Message
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                fontSize: 12,
                fontFamily: log.level == 'tool' ? 'monospace' : null,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _logStyle(String level) {
    switch (level) {
      case 'ok':
        return (AppColors.success, Icons.check_circle_outline);
      case 'error':
        return (AppColors.error, Icons.error_outline);
      case 'step':
        return (AppColors.accent, Icons.arrow_right);
      case 'tool':
        return (AppColors.warning, Icons.build);
      case 'progress':
        return (AppColors.agentActive, Icons.trending_up);
      case 'input':
        return (AppColors.info, Icons.input);
      case 'result':
        return (AppColors.success, Icons.check_circle);
      default:
        return (AppColors.textTertiary, Icons.circle);
    }
  }

  Widget _buildTimelinePanel(List<dynamic> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'No timeline events yet.\nRun a task to see activity.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildTimelineEventCard(event),
        );
      },
    );
  }

  Widget _buildTimelineEventCard(dynamic event) {
    return GlassCard(
      variant: GlassCardVariant.inline,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _colorForEventType(event.type).withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              _iconForEventType(event.type),
              size: 16,
              color: _colorForEventType(event.type),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            event.timeAgo,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForEventType(ActivityType type) {
    switch (type) {
      case ActivityType.memoryCreated:
        return Icons.psychology_outlined;
      case ActivityType.agentStarted:
        return Icons.play_arrow;
      case ActivityType.agentCompleted:
        return Icons.check_circle_outline;
      case ActivityType.agentFailed:
        return Icons.error_outline;
      case ActivityType.automationExecuted:
        return Icons.autorenew;
      case ActivityType.desktopActionExecuted:
        return Icons.computer;
      case ActivityType.voiceSessionStarted:
        return Icons.mic;
      case ActivityType.systemEvent:
        return Icons.build;
      default:
        return Icons.circle;
    }
  }

  Color _colorForEventType(ActivityType type) {
    switch (type) {
      case ActivityType.memoryCreated:
        return AppColors.accent;
      case ActivityType.agentStarted:
        return AppColors.agentActive;
      case ActivityType.agentCompleted:
        return AppColors.success;
      case ActivityType.agentFailed:
        return AppColors.error;
      case ActivityType.automationExecuted:
        return AppColors.warning;
      case ActivityType.systemEvent:
        return AppColors.info;
      default:
        return AppColors.textTertiary;
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

class ToolCall {
  final DateTime timestamp;
  final String name;
  final String params;
  final String result;
  final int durationMs;

  const ToolCall({
    required this.timestamp,
    required this.name,
    required this.params,
    required this.result,
    required this.durationMs,
  });
}
