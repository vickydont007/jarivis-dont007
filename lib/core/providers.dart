import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/orb_state.dart';
import '../core/services/timeline_service.dart';
import '../core/services/orb_state_manager.dart';
import '../core/services/agent_manager.dart';
import '../core/services/memory_service.dart';
import '../core/services/briefing_service.dart';
import '../core/services/agent_executor.dart';
import '../core/services/persistent_scheduler.dart';
import '../core/services/daily_briefing_service.dart';
import '../core/services/agent_collaboration.dart';
import '../core/services/memory_search.dart';
import '../core/services/memory_search.dart' show MemorySearchResult;
import '../core/repositories/timeline_repository.dart';
import '../core/repositories/agent_repository.dart';
import '../core/repositories/task_repository.dart';
import '../core/repositories/memory_repository.dart';

// ─── Repository Providers ──────────────────────────────────────────

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return InMemoryTimelineRepository();
});

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return InMemoryAgentRepository();
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return InMemoryTaskRepository();
});

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return InMemoryMemoryRepository();
});

// ─── Core Service Providers ────────────────────────────────────────

final timelineServiceProvider = Provider<TimelineService>((ref) {
  final repo = ref.watch(timelineRepositoryProvider);
  return TimelineService(repository: repo);
});

final orbStateManagerProvider = Provider<OrbStateManager>((ref) {
  return OrbStateManager();
});

final agentManagerProvider = Provider<AgentManager>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  final orb = ref.watch(orbStateManagerProvider);
  return AgentManager(
    timeline: timeline,
    orb: orb,
  );
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  return MemoryService(timeline: timeline);
});

final briefingServiceProvider = Provider<BriefingService>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  final agents = ref.watch(agentManagerProvider);
  final memory = ref.watch(memoryServiceProvider);
  return BriefingService(
    timeline: timeline,
    agents: agents,
    memory: memory,
  );
});

// ─── Stream Providers (for reactive UI) ────────────────────────────

final orbStateProvider = StreamProvider.autoDispose<OrbState>((ref) {
  final orbManager = ref.watch(orbStateManagerProvider);
  return orbManager.stateStream;
});

final activityTimelineProvider = FutureProvider.autoDispose<List>((ref) async {
  final timeline = ref.watch(timelineServiceProvider);
  return timeline.getRecent(limit: 30);
});

final activityStreamProvider = StreamProvider.autoDispose((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  return timeline.eventStream;
});

final agentsProvider = FutureProvider.autoDispose<List>((ref) async {
  final agentManager = ref.watch(agentManagerProvider);
  return agentManager.getAllAgents();
});

final agentsStreamProvider = StreamProvider.autoDispose((ref) {
  final agentManager = ref.watch(agentManagerProvider);
  return agentManager.watchAgents();
});

final tasksProvider = FutureProvider.autoDispose<List>((ref) async {
  final agentManager = ref.watch(agentManagerProvider);
  return agentManager.getRecentTasks(limit: 20);
});

final memoriesProvider = FutureProvider.autoDispose<List>((ref) async {
  final memoryService = ref.watch(memoryServiceProvider);
  return memoryService.recentMemories(limit: 50);
});

final memoriesStreamProvider = StreamProvider.autoDispose((ref) {
  final memoryService = ref.watch(memoryServiceProvider);
  return memoryService.watchMemories();
});

final briefingProvider = FutureProvider.autoDispose((ref) async {
  final briefingService = ref.watch(briefingServiceProvider);
  return briefingService.generateBriefing();
});

// ─── Phase 5: Persistent Scheduler ────────────────────────────────

final persistentSchedulerProvider = Provider<PersistentScheduler>((ref) {
  return PersistentScheduler();
});

// ─── Phase 5: Daily Briefing Service ──────────────────────────────

final dailyBriefingServiceProvider = Provider<DailyBriefingService>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  final agents = ref.watch(agentManagerProvider);
  final memory = ref.watch(memoryServiceProvider);
  return DailyBriefingService(
    timeline: timeline,
    agents: agents,
    memory: memory,
  );
});

// ─── Phase 5: Agent Collaboration ─────────────────────────────────

final agentCollaborationProvider = Provider<AgentCollaboration>((ref) {
  final agents = ref.watch(agentManagerProvider);
  final timeline = ref.watch(timelineServiceProvider);
  final orb = ref.watch(orbStateManagerProvider);
  return AgentCollaboration(
    agentManager: agents,
    timeline: timeline,
    orb: orb,
  );
});

// ─── Phase 5: Memory Search ───────────────────────────────────────

final memorySearchProvider = Provider<MemorySearch>((ref) {
  return MemorySearch();
});

// ─── Phase 5: Daily Briefing Provider ─────────────────────────────

final dailyBriefingProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(dailyBriefingServiceProvider);
  return service.generateBriefing();
});

// ─── Phase 5: Execution History ───────────────────────────────────

final executionHistoryProvider = FutureProvider.autoDispose<List>((ref) async {
  final scheduler = ref.watch(persistentSchedulerProvider);
  return scheduler.getExecutionHistory(limit: 30);
});

// ─── Phase 5: Active Schedules ────────────────────────────────────

final activeSchedulesProvider = FutureProvider.autoDispose<List>((ref) async {
  final scheduler = ref.watch(persistentSchedulerProvider);
  return scheduler.getActiveSchedules();
});

// ─── Phase 5: Memory Search Provider ──────────────────────────────

final memorySearchResultsProvider = FutureProvider.autoDispose.family<List<MemorySearchResult>, String>((ref, query) async {
  final search = ref.watch(memorySearchProvider);
  return search.search(query, limit: 10);
});
