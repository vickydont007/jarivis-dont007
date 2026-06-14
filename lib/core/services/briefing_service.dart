import '../models/daily_briefing.dart';
import '../models/activity_event.dart';
import '../models/agent.dart';
import '../models/memory_record.dart';
import 'timeline_service.dart';
import 'agent_manager.dart';
import 'memory_service.dart';

class BriefingService {
  final TimelineService _timeline;
  final AgentManager _agents;
  final MemoryService _memory;

  BriefingService({
    required TimelineService timeline,
    required AgentManager agents,
    required MemoryService memory,
  })  : _timeline = timeline,
        _agents = agents,
        _memory = memory;

  Future<DailyBriefing> generateBriefing() async {
    final now = DateTime.now();
    final greeting = _getGreeting(now);

    final todayEvents = await _timeline.getTodayEvents();
    final allAgents = await _agents.getAllAgents();
    final allMemories = await _memory.getAll();
    final recentTasks = await _agents.getRecentTasks(limit: 10);

    final activeAgents = allAgents.where((a) => a.isActive).length;
    final completedTasks = recentTasks.where((t) => t.isDone).length;
    final pendingTasks = recentTasks.where((t) => t.isRunning).length;

    final items = <BriefingItem>[];

    // Agent activity
    final agentEvents = todayEvents
        .where((e) =>
            e.type == ActivityType.agentCompleted ||
            e.type == ActivityType.agentStarted)
        .toList();
    if (agentEvents.isNotEmpty) {
      final completed = agentEvents.where((e) => e.type == ActivityType.agentCompleted).length;
      if (completed > 0) {
        items.add(BriefingItem(
          icon: '🤖',
          title: '$completed agent task${completed > 1 ? 's' : ''} completed',
          description: 'Your agents have been productive',
          type: BriefingItemType.agentActivity,
        ));
      }
    }

    // Memory updates
    final memoryEvents = todayEvents
        .where((e) => e.type == ActivityType.memoryCreated)
        .toList();
    if (memoryEvents.isNotEmpty) {
      items.add(BriefingItem(
        icon: '🧠',
        title: '${memoryEvents.length} new memories learned',
        description: 'Your AI is getting to know you better',
        type: BriefingItemType.memoryUpdate,
      ));
    }

    // Automation events
    final automationEvents = todayEvents
        .where((e) => e.type == ActivityType.automationExecuted)
        .toList();
    if (automationEvents.isNotEmpty) {
      items.add(BriefingItem(
        icon: '⚙️',
        title: '${automationEvents.length} automations ran',
        description: 'Your automated workflows executed',
        type: BriefingItemType.automationEvent,
      ));
    }

    // If no events today
    if (items.isEmpty) {
      items.add(BriefingItem(
        icon: '👋',
        title: 'Quiet day so far',
        description: 'Your AI has been waiting for you',
        type: BriefingItemType.systemEvent,
      ));
    }

    final summary = _buildSummary(items);
    final stats = BriefingStats(
      totalMemories: allMemories.length,
      activeAgents: activeAgents,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      automationsRunning: automationEvents.length,
      dominantMood: _getDominantMood(todayEvents),
    );

    return DailyBriefing(
      date: now,
      greeting: greeting,
      summary: summary,
      items: items,
      stats: stats,
      generatedAt: now,
    );
  }

  String _getGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _buildSummary(List<BriefingItem> items) {
    if (items.isEmpty) return 'All quiet on the system front.';
    if (items.length == 1) return items.first.description;
    return '${items.length} things happened while you were away.';
  }

  String _getDominantMood(List<ActivityEvent> events) {
    // Simple heuristic based on activity types
    final hasCompleted = events.any((e) => e.type == ActivityType.agentCompleted);
    final hasFailed = events.any((e) => e.type == ActivityType.agentFailed);
    final hasMemory = events.any((e) => e.type == ActivityType.memoryCreated);

    if (hasFailed) return 'Busy';
    if (hasCompleted && hasMemory) return 'Productive';
    if (hasCompleted) return 'Active';
    if (hasMemory) return 'Learning';
    return 'Idle';
  }
}
