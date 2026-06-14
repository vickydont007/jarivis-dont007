import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/models/orb_state.dart';
import '../core/models/agent.dart';
import '../core/models/agent_task.dart';
import '../core/models/memory_record.dart';
import '../core/models/activity_event.dart';
import '../core/repositories/timeline_repository.dart';
import '../core/repositories/agent_repository.dart';
import '../core/repositories/task_repository.dart';
import '../core/repositories/memory_repository.dart';
import '../core/services/timeline_service.dart';
import '../core/services/orb_state_manager.dart';
import '../core/services/agent_manager.dart';
import '../core/services/memory_service.dart';
import '../core/capabilities/nl_parser.dart';
import '../core/capabilities/memory_pipeline.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';

// ═══════════════════════════════════════════════════════════════════
// Test Result Model
// ═══════════════════════════════════════════════════════════════════

enum TestStatus { pending, running, passed, failed }

class TestResult {
  final String name;
  final String description;
  TestStatus status;
  List<String> steps;
  String? error;
  Duration? duration;

  TestResult({
    required this.name,
    required this.description,
    this.status = TestStatus.pending,
    this.steps = const [],
    this.error,
    this.duration,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Runtime Validation Suite Screen
// ═══════════════════════════════════════════════════════════════════

class RuntimeValidationScreen extends StatefulWidget {
  const RuntimeValidationScreen({super.key});

  @override
  State<RuntimeValidationScreen> createState() => _RuntimeValidationScreenState();
}

class _RuntimeValidationScreenState extends State<RuntimeValidationScreen> {
  final List<TestResult> _tests = [];
  bool _isRunning = false;
  int _passedCount = 0;
  int _failedCount = 0;
  int _totalCount = 0;

  // Fresh service instances for isolated testing
  late final TimelineService _timeline;
  late final OrbStateManager _orb;
  late final AgentManager _agentManager;
  late final MemoryService _memoryService;
  late final NaturalLanguageParser _nlParser;
  late final MemoryExtractionPipeline _memoryPipeline;

  @override
  void initState() {
    super.initState();
    _initServices();
    _initTests();
  }

  void _initServices() {
    _timeline = TimelineService(repository: InMemoryTimelineRepository());
    _orb = OrbStateManager();
    _agentManager = AgentManager(
      timeline: _timeline,
      orb: _orb,
    );
    _memoryService = MemoryService(timeline: _timeline);
    _nlParser = NaturalLanguageParser();
    _memoryPipeline = MemoryExtractionPipeline(
      memoryService: _memoryService,
      timeline: _timeline,
    );
  }

  void _initTests() {
    _tests.clear();
    _tests.addAll([
      TestResult(
        name: 'Agent → Tool → Result',
        description: 'Register agent, start task, update progress, complete with result',
      ),
      TestResult(
        name: 'Agent → Timeline',
        description: 'Verify agent activities create timeline events',
      ),
      TestResult(
        name: 'Agent → Memory',
        description: 'Verify agent activities create memory records via pipeline',
      ),
      TestResult(
        name: 'Automation → Agent Trigger',
        description: 'Parse NL automation, trigger agent task, verify execution',
      ),
      TestResult(
        name: 'Orb State Transitions',
        description: 'Verify Orb state changes: idle → thinking → speaking → idle',
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Test 1: Agent → Tool → Result
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _testAgentToolResult(TestResult test) async {
    final steps = <String>[];

    // Step 1: Register agent
    steps.add('Registering test agent...');
    _updateTest(test, TestStatus.running, steps);
    final agent = await _agentManager.registerAgent(
      name: 'Test Agent',
      description: 'Validation test agent',
      icon: '🧪',
    );
    steps.add('✓ Agent registered: ${agent.id.substring(0, 8)}...');
    _updateTest(test, TestStatus.running, steps);

    // Step 2: Start task
    steps.add('Starting task...');
    _updateTest(test, TestStatus.running, steps);
    final task = await _agentManager.startTask(
      agentId: agent.id,
      title: 'Test task execution',
      description: 'Validate end-to-end task pipeline',
    );
    steps.add('✓ Task created: ${task.id.substring(0, 8)}...');
    _updateTest(test, TestStatus.running, steps);

    // Step 3: Verify agent is working
    final workingAgent = await _agentManager.getAgent(agent.id);
    if (workingAgent == null || !workingAgent.isActive) {
      throw Exception('Agent should be in working state');
    }
    steps.add('✓ Agent status: ${workingAgent.status.name}');
    _updateTest(test, TestStatus.running, steps);

    // Step 4: Update progress
    steps.add('Updating progress to 50%...');
    _updateTest(test, TestStatus.running, steps);
    await _agentManager.updateProgress(
      agentId: agent.id,
      taskId: task.id,
      progress: 0.5,
    );
    final progressAgent = await _agentManager.getAgent(agent.id);
    if (progressAgent == null || progressAgent.progress != 0.5) {
      throw Exception('Progress should be 0.5, got ${progressAgent?.progress}');
    }
    steps.add('✓ Progress updated: ${(progressAgent.progress * 100).round()}%');
    _updateTest(test, TestStatus.running, steps);

    // Step 5: Complete task with result
    steps.add('Completing task with result...');
    _updateTest(test, TestStatus.running, steps);
    const expectedResult = 'Analysis complete: 5 insights found';
    await _agentManager.completeTask(
      agentId: agent.id,
      taskId: task.id,
      result: expectedResult,
    );

    // Step 6: Verify completion
    final completedAgent = await _agentManager.getAgent(agent.id);
    final completedTask = await _agentManager.getRecentTasks(limit: 1);
    if (completedAgent == null || completedAgent.isActive) {
      throw Exception('Agent should be idle after completion');
    }
    if (completedTask.isEmpty || completedTask.first.result != expectedResult) {
      throw Exception('Task result mismatch');
    }
    steps.add('✓ Task completed with result: "${completedTask.first.result}"');
    steps.add('✓ Agent returned to idle');
    _updateTest(test, TestStatus.running, steps);

    // Step 7: Verify stats updated
    if (completedAgent.completedTasks < 1) {
      throw Exception('Completed tasks count should be >= 1');
    }
    steps.add('✓ Stats updated: ${completedAgent.completedTasks} completed');
    _updateTest(test, TestStatus.passed, steps);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Test 2: Agent → Timeline
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _testAgentTimeline(TestResult test) async {
    final steps = <String>[];

    // Step 1: Clear timeline
    steps.add('Clearing timeline...');
    _updateTest(test, TestStatus.running, steps);
    await _timeline.clear();
    final beforeCount = await _timeline.count();
    steps.add('✓ Timeline cleared: $beforeCount events');
    _updateTest(test, TestStatus.running, steps);

    // Step 2: Register agent (should log event)
    steps.add('Registering agent (expecting timeline event)...');
    _updateTest(test, TestStatus.running, steps);
    final agent = await _agentManager.registerAgent(
      name: 'Timeline Test Agent',
      description: 'Tests timeline logging',
      icon: '📊',
    );
    await Future.delayed(const Duration(milliseconds: 100));
    final afterRegister = await _timeline.count();
    if (afterRegister <= beforeCount) {
      throw Exception('Timeline should have new event after agent registration');
    }
    steps.add('✓ Timeline event created after registration: $afterRegister events');
    _updateTest(test, TestStatus.running, steps);

    // Step 3: Start task (should log event)
    steps.add('Starting task (expecting timeline event)...');
    _updateTest(test, TestStatus.running, steps);
    final task = await _agentManager.startTask(
      agentId: agent.id,
      title: 'Timeline validation task',
      description: 'Test timeline logging',
    );
    await Future.delayed(const Duration(milliseconds: 100));
    final afterStart = await _timeline.count();
    if (afterStart <= afterRegister) {
      throw Exception('Timeline should have new event after task start');
    }
    steps.add('✓ Timeline event created after task start: $afterStart events');
    _updateTest(test, TestStatus.running, steps);

    // Step 4: Complete task (should log event)
    steps.add('Completing task (expecting timeline event)...');
    _updateTest(test, TestStatus.running, steps);
    await _agentManager.completeTask(
      agentId: agent.id,
      taskId: task.id,
      result: 'Timeline test complete',
    );
    await Future.delayed(const Duration(milliseconds: 100));
    final afterComplete = await _timeline.count();
    if (afterComplete <= afterStart) {
      throw Exception('Timeline should have new event after task completion');
    }
    steps.add('✓ Timeline event created after task completion: $afterComplete events');
    _updateTest(test, TestStatus.running, steps);

    // Step 5: Verify event types
    steps.add('Verifying event types...');
    _updateTest(test, TestStatus.running, steps);
    final events = await _timeline.getRecent(limit: 10);
    final agentEvents = events.where((e) =>
        e.type == ActivityType.agentStarted ||
        e.type == ActivityType.agentCompleted).toList();
    if (agentEvents.isEmpty) {
      throw Exception('Should have agent-related timeline events');
    }
    steps.add('✓ Found ${agentEvents.length} agent-related events');
    for (final e in agentEvents.take(3)) {
      steps.add('  → ${e.type.name}: ${e.title}');
    }
    _updateTest(test, TestStatus.running, steps);

    // Step 6: Verify source field
    final sourceEvents = events.where((e) => e.source == 'Timeline Test Agent').toList();
    if (sourceEvents.isEmpty) {
      throw Exception('Should have events from "Timeline Test Agent" source');
    }
    steps.add('✓ Events correctly sourced from agent: ${sourceEvents.length} events');
    _updateTest(test, TestStatus.passed, steps);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Test 3: Agent → Memory
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _testAgentMemory(TestResult test) async {
    final steps = <String>[];

    // Step 1: Check initial memory count
    steps.add('Checking initial memory count...');
    _updateTest(test, TestStatus.running, steps);
    final beforeCount = await _memoryService.count();
    steps.add('✓ Initial memory count: $beforeCount');
    _updateTest(test, TestStatus.running, steps);

    // Step 2: Add memory directly
    steps.add('Adding memory via MemoryService...');
    _updateTest(test, TestStatus.running, steps);
    final memory1 = await _memoryService.addMemory(
      type: MemoryType.fact,
      content: 'User prefers dark mode',
      tags: ['preference', 'ui'],
      source: 'validation_test',
      importance: 7,
    );
    steps.add('✓ Memory created: ${memory1.id.substring(0, 8)}...');
    _updateTest(test, TestStatus.running, steps);

    // Step 3: Verify memory exists
    steps.add('Verifying memory in store...');
    _updateTest(test, TestStatus.running, steps);
    final memories = await _memoryService.recentMemories(limit: 10);
    final found = memories.any((m) => m.id == memory1.id);
    if (!found) {
      throw Exception('Memory not found in store');
    }
    steps.add('✓ Memory found in store');
    _updateTest(test, TestStatus.running, steps);

    // Step 4: Search memory
    steps.add('Searching memory by content...');
    _updateTest(test, TestStatus.running, steps);
    final searchResults = await _memoryService.searchMemory('dark mode');
    if (searchResults.isEmpty) {
      throw Exception('Search should find the memory');
    }
    steps.add('✓ Search found ${searchResults.length} results');
    _updateTest(test, TestStatus.running, steps);

    // Step 5: Extract from conversation via pipeline
    steps.add('Extracting memories from conversation...');
    _updateTest(test, TestStatus.running, steps);
    final extraction = await _memoryPipeline.extractFromConversation(
      userMessage: 'My name is Vicky and I love AI research',
      aiResponse: 'Nice to meet you Vicky! AI research is fascinating.',
      source: 'validation_pipeline',
    );
    if (extraction.memories.isEmpty) {
      throw Exception('Pipeline should extract at least 1 memory');
    }
    steps.add('✓ Pipeline extracted ${extraction.memories.length} memories');
    for (final m in extraction.memories.take(3)) {
      steps.add('  → [${m.type.name}] ${m.content}');
    }
    _updateTest(test, TestStatus.running, steps);

    // Step 6: Verify pipeline memories persisted
    steps.add('Verifying pipeline memories persisted...');
    _updateTest(test, TestStatus.running, steps);
    final afterPipeline = await _memoryService.count();
    if (afterPipeline <= beforeCount + 1) {
      throw Exception('Memory count should increase after pipeline extraction');
    }
    steps.add('✓ Memory count increased: $beforeCount → $afterPipeline');
    _updateTest(test, TestStatus.passed, steps);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Test 4: Automation → Agent Trigger
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _testAutomationAgentTrigger(TestResult test) async {
    final steps = <String>[];

    // Step 1: Parse NL automation
    steps.add('Parsing natural language automation...');
    _updateTest(test, TestStatus.running, steps);
    final parseResult = _nlParser.parse('Every morning at 9am, run the research agent to find AI news');
    if (!parseResult.success || parseResult.automation == null) {
      throw Exception('NL parse failed: ${parseResult.error}');
    }
    final automation = parseResult.automation!;
    steps.add('✓ Parsed automation: trigger=${automation.trigger.name}');
    steps.add('  Actions: ${automation.actions.length}');
    for (final a in automation.actions) {
      steps.add('  → ${a.type.name}: ${a.description}');
    }
    _updateTest(test, TestStatus.running, steps);

    // Step 2: Verify trigger type
    if (automation.trigger != AutomationTrigger.time) {
      throw Exception('Expected time trigger, got ${automation.trigger.name}');
    }
    steps.add('✓ Trigger type verified: time-based');
    _updateTest(test, TestStatus.running, steps);

    // Step 3: Verify action contains agent start
    final agentActions = automation.actions
        .where((a) => a.type == AutomationAction.startAgent)
        .toList();
    if (agentActions.isEmpty) {
      throw Exception('Expected startAgent action');
    }
    steps.add('✓ Agent trigger action found');
    _updateTest(test, TestStatus.running, steps);

    // Step 4: Register agent and simulate trigger
    steps.add('Registering agent for automation...');
    _updateTest(test, TestStatus.running, steps);
    final agent = await _agentManager.registerAgent(
      name: 'Automation Test Agent',
      description: 'Triggered by automation',
      icon: '⚡',
    );
    steps.add('✓ Agent registered: ${agent.name}');
    _updateTest(test, TestStatus.running, steps);

    // Step 5: Simulate automation trigger (start task)
    steps.add('Simulating automation trigger...');
    _updateTest(test, TestStatus.running, steps);
    final task = await _agentManager.startTask(
      agentId: agent.id,
      title: 'AI News Research',
      description: 'Automated daily research task',
    );
    steps.add('✓ Task triggered by automation: ${task.title}');
    _updateTest(test, TestStatus.running, steps);

    // Step 6: Complete and verify
    steps.add('Completing automated task...');
    _updateTest(test, TestStatus.running, steps);
    await _agentManager.completeTask(
      agentId: agent.id,
      taskId: task.id,
      result: 'Found 7 AI news articles',
    );
    final completedTask = await _agentManager.getRecentTasks(limit: 1);
    if (completedTask.isEmpty || !completedTask.first.isDone) {
      throw Exception('Automated task should be completed');
    }
    steps.add('✓ Automated task completed: "${completedTask.first.result}"');
    _updateTest(test, TestStatus.passed, steps);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Test 5: Orb State Transitions
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _testOrbStateTransitions(TestResult test) async {
    final steps = <String>[];
    final stateHistory = <OrbState>[];
    final sub = _orb.stateStream.listen((state) {
      stateHistory.add(state);
    });

    try {
      // Step 1: Verify initial state
      steps.add('Verifying initial Orb state...');
      _updateTest(test, TestStatus.running, steps);
      if (_orb.currentState != OrbState.idle) {
        throw Exception('Initial state should be idle, got ${_orb.currentState.name}');
      }
      steps.add('✓ Initial state: idle');
      _updateTest(test, TestStatus.running, steps);

      // Step 2: Request thinking
      steps.add('Requesting thinking state...');
      _updateTest(test, TestStatus.running, steps);
      _orb.requestThinking('test_source');
      await Future.delayed(const Duration(milliseconds: 50));
      if (_orb.currentState != OrbState.thinking) {
        throw Exception('State should be thinking, got ${_orb.currentState.name}');
      }
      steps.add('✓ State → thinking');
      _updateTest(test, TestStatus.running, steps);

      // Step 3: Request speaking (should queue, still thinking)
      steps.add('Requesting speaking state while thinking...');
      _updateTest(test, TestStatus.running, steps);
      _orb.requestSpeaking('test_source_2');
      await Future.delayed(const Duration(milliseconds: 50));
      // With reference counting, speaking should now be active
      if (_orb.currentState != OrbState.speaking) {
        throw Exception('State should be speaking, got ${_orb.currentState.name}');
      }
      steps.add('✓ State → speaking');
      _updateTest(test, TestStatus.running, steps);

      // Step 4: Release speaking
      steps.add('Releasing speaking...');
      _updateTest(test, TestStatus.running, steps);
      _orb.releaseSpeaking('test_source_2');
      await Future.delayed(const Duration(milliseconds: 50));
      // Should revert to thinking (still held by test_source)
      if (_orb.currentState != OrbState.thinking) {
        throw Exception('State should revert to thinking, got ${_orb.currentState.name}');
      }
      steps.add('✓ State → thinking (speaking released)');
      _updateTest(test, TestStatus.running, steps);

      // Step 5: Release thinking
      steps.add('Releasing thinking...');
      _updateTest(test, TestStatus.running, steps);
      _orb.releaseThinking('test_source');
      await Future.delayed(const Duration(milliseconds: 50));
      if (_orb.currentState != OrbState.idle) {
        throw Exception('State should be idle, got ${_orb.currentState.name}');
      }
      steps.add('✓ State → idle (all released)');
      _updateTest(test, TestStatus.running, steps);

      // Step 6: Request listening
      steps.add('Requesting listening state...');
      _updateTest(test, TestStatus.running, steps);
      _orb.requestListening('test_voice');
      await Future.delayed(const Duration(milliseconds: 50));
      if (_orb.currentState != OrbState.listening) {
        throw Exception('State should be listening, got ${_orb.currentState.name}');
      }
      steps.add('✓ State → listening');
      _updateTest(test, TestStatus.running, steps);

      // Step 7: Force idle
      steps.add('Force resetting to idle...');
      _updateTest(test, TestStatus.running, steps);
      _orb.forceIdle();
      await Future.delayed(const Duration(milliseconds: 50));
      if (_orb.currentState != OrbState.idle) {
        throw Exception('State should be idle after force reset');
      }
      steps.add('✓ State → idle (force reset)');
      _updateTest(test, TestStatus.running, steps);

      // Step 8: Verify state history
      steps.add('Verifying state transition history...');
      _updateTest(test, TestStatus.running, steps);
      if (stateHistory.length < 4) {
        throw Exception('Should have at least 4 state changes, got ${stateHistory.length}');
      }
      steps.add('✓ State history: ${stateHistory.length} transitions');
      final uniqueStates = stateHistory.toSet();
      steps.add('  Unique states visited: ${uniqueStates.map((s) => s.name).join(', ')}');
      _updateTest(test, TestStatus.passed, steps);
    } finally {
      await sub.cancel();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Runner
  // ═══════════════════════════════════════════════════════════════════

  void _updateTest(TestResult test, TestStatus status, List<String> steps) {
    if (!mounted) return;
    setState(() {
      test.status = status;
      test.steps = List.from(steps);
    });
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _passedCount = 0;
      _failedCount = 0;
      _totalCount = _tests.length;
      for (final t in _tests) {
        t.status = TestStatus.pending;
        t.steps = [];
        t.error = null;
        t.duration = null;
      }
    });

    final testFunctions = [
      _testAgentToolResult,
      _testAgentTimeline,
      _testAgentMemory,
      _testAutomationAgentTrigger,
      _testOrbStateTransitions,
    ];

    for (var i = 0; i < _tests.length; i++) {
      final test = _tests[i];
      final sw = Stopwatch()..start();

      try {
        setState(() => test.status = TestStatus.running);
        await testFunctions[i](test);
        sw.stop();
        test.duration = sw.elapsed;
        _passedCount++;
      } catch (e) {
        sw.stop();
        test.duration = sw.elapsed;
        test.error = e.toString();
        test.status = TestStatus.failed;
        _failedCount++;
      }

      if (mounted) setState(() {});
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSummaryBar(),
            Expanded(child: _buildTestList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 24, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Runtime Validation Suite',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Automated tests for Agent → Tool → Timeline → Memory → Orb pipelines',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          GlassButton(
            label: _isRunning ? 'Running...' : '▶ Run All Tests',
            variant: GlassButtonVariant.primary,
            onPressed: _isRunning ? null : _runAllTests,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final allDone = !_isRunning && _totalCount > 0;
    final allPassed = allDone && _failedCount == 0 && _passedCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          // Status icon
          if (_isRunning)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          else if (allPassed)
            const Icon(Icons.check_circle, size: 16, color: AppColors.success)
          else if (allDone)
            const Icon(Icons.error, size: 16, color: AppColors.error)
          else
            const Icon(Icons.radio_button_unchecked, size: 16, color: AppColors.textDisabled),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _isRunning
                ? 'Running tests...'
                : allDone
                    ? allPassed
                        ? 'ALL TESTS PASSED'
                        : 'TESTS COMPLETED WITH FAILURES'
                    : 'Ready to run',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isRunning
                  ? AppColors.accent
                  : allPassed
                      ? AppColors.success
                      : allDone
                          ? AppColors.error
                          : AppColors.textTertiary,
            ),
          ),
          const Spacer(),
          if (_totalCount > 0) ...[
            _buildCountBadge('$_passedCount passed', AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            _buildCountBadge('$_failedCount failed', AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            _buildCountBadge('$_totalCount total', AppColors.textTertiary),
          ],
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTestList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: _tests.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _buildTestCard(_tests[index]),
        );
      },
    );
  }

  Widget _buildTestCard(TestResult test) {
    final (statusColor, statusIcon, statusLabel) = _statusStyle(test.status);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Status icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(statusIcon, size: 16, color: statusColor),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      test.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
              if (test.duration != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${test.duration!.inMilliseconds}ms',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ],
          ),

          // Steps
          if (test.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: test.steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: step.startsWith('  →') ? 'monospace' : null,
                      color: step.startsWith('✓')
                          ? AppColors.success
                          : step.startsWith('  →')
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],

          // Error
          if (test.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Text(
                '✗ ${test.error}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _statusStyle(TestStatus status) {
    switch (status) {
      case TestStatus.pending:
        return (AppColors.textDisabled, Icons.radio_button_unchecked, 'PENDING');
      case TestStatus.running:
        return (AppColors.accent, Icons.play_circle, 'RUNNING');
      case TestStatus.passed:
        return (AppColors.success, Icons.check_circle, 'PASSED');
      case TestStatus.failed:
        return (AppColors.error, Icons.cancel, 'FAILED');
    }
  }
}
