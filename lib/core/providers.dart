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
import '../core/services/proactive_engine.dart';
import '../core/services/knowledge_hub.dart';
import '../core/services/watchlist_monitor.dart';
import '../core/services/project_analyzer.dart';
import '../core/services/email_service.dart';
import '../core/services/calendar_intel.dart';
import '../core/services/external_knowledge.dart';
import '../core/services/memory_consolidation.dart';
import '../core/services/calendar_service.dart';
import '../providers/app_provider.dart';

// ─── Core Service Providers (read from AppState) ─────────────────

final orbStateManagerProvider = Provider<OrbStateManager>((ref) {
  return OrbStateManager();
});

final timelineServiceProvider = Provider<TimelineService>((ref) {
  final appState = ref.watch(appStateProvider);
  return appState.timelineService ?? TimelineService();
});

final agentManagerProvider = Provider<AgentManager>((ref) {
  final appState = ref.watch(appStateProvider);
  final timeline = ref.watch(timelineServiceProvider);
  final orb = ref.watch(orbStateManagerProvider);
  return appState.agentManager ?? AgentManager(
    timeline: timeline,
    orb: orb,
  );
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  final appState = ref.watch(appStateProvider);
  final timeline = ref.watch(timelineServiceProvider);
  return appState.memoryService ?? MemoryService(timeline: timeline);
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  final appState = ref.watch(appStateProvider);
  return appState.calendarService ?? CalendarService();
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
  final calendarService = ref.watch(calendarServiceProvider);
  return DailyBriefingService(
    timeline: timeline,
    agents: agents,
    memory: memory,
    calendarService: calendarService,
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

// ─── Phase 7: Proactive Engine ───────────────────────────────────

final watchlistMonitorProvider = Provider<WatchlistMonitor>((ref) {
  return WatchlistMonitor();
});

final projectAnalyzerProvider = Provider<ProjectAnalyzer>((ref) {
  return ProjectAnalyzer();
});

final emailServiceProvider = Provider<EmailService>((ref) {
  return EmailService();
});

final externalKnowledgeProvider = Provider<ExternalKnowledge>((ref) {
  return ExternalKnowledge();
});

final calendarIntelProvider = Provider<CalendarIntel>((ref) {
  final memory = ref.watch(memoryServiceProvider);
  final memorySearch = ref.watch(memorySearchProvider);
  final knowledgeHub = ref.watch(knowledgeHubProvider);
  final email = ref.watch(emailServiceProvider);
  return CalendarIntel(
    memory: memory,
    memorySearch: memorySearch,
    knowledgeHub: knowledgeHub,
    emailService: email,
  );
});

final proactiveEngineProvider = Provider<ProactiveEngine>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  final memory = ref.watch(memoryServiceProvider);
  final memorySearch = ref.watch(memorySearchProvider);
  final orb = ref.watch(orbStateManagerProvider);
  final watchlist = ref.watch(watchlistMonitorProvider);
  final analyzer = ref.watch(projectAnalyzerProvider);
  final email = ref.watch(emailServiceProvider);
  final calendarIntel = ref.watch(calendarIntelProvider);
  final externalKnowledge = ref.watch(externalKnowledgeProvider);
  return ProactiveEngine(
    timeline: timeline,
    memory: memory,
    memorySearch: memorySearch,
    orb: orb,
    watchlistMonitor: watchlist,
    projectAnalyzer: analyzer,
    emailService: email,
    calendarIntel: calendarIntel,
    externalKnowledge: externalKnowledge,
  );
});

// ─── Phase 7: Knowledge Hub ──────────────────────────────────────

final knowledgeHubProvider = Provider<KnowledgeHub>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  final memory = ref.watch(memoryServiceProvider);
  final memorySearch = ref.watch(memorySearchProvider);
  final externalKnowledge = ref.watch(externalKnowledgeProvider);
  return KnowledgeHub(
    timeline: timeline,
    memory: memory,
    memorySearch: memorySearch,
    externalKnowledge: externalKnowledge,
  );
});

// ─── Phase 7: Proactive Insights Stream ──────────────────────────

final proactiveInsightsProvider = StreamProvider.autoDispose<Insight>((ref) {
  final engine = ref.watch(proactiveEngineProvider);
  return engine.insightStream;
});

// ─── Phase 7: Top Insights ──────────────────────────────────────

final topInsightsProvider = FutureProvider.autoDispose<List<Insight>>((ref) async {
  final engine = ref.watch(proactiveEngineProvider);
  await Future.delayed(const Duration(milliseconds: 100));
  return engine.getTopInsights(limit: 5);
});

// ─── Phase 7: Unified Context ───────────────────────────────────

final unifiedContextProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final hub = ref.watch(knowledgeHubProvider);
  return hub.getUnifiedContext();
});

// ─── Memory Consolidation ───────────────────────────────────────

final memoryConsolidationProvider = Provider<MemoryConsolidationService?>((ref) {
  return ref.watch(appStateProvider.notifier).memoryConsolidation;
});

// ─── Calendar Providers ─────────────────────────────────────────

final calendarEventsProvider = FutureProvider.autoDispose<List>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return calendarService.getAllEvents();
});

final todayEventsProvider = FutureProvider.autoDispose<List>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return calendarService.getTodayEvents();
});

final upcomingEventsProvider = FutureProvider.autoDispose<List>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return calendarService.getUpcomingEvents(limit: 10);
});
