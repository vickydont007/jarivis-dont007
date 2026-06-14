import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'services/timeline_service.dart';
import 'services/orb_state_manager.dart';
import 'services/memory_service.dart';
import 'capabilities/capabilities.dart';

// ─── Capability Providers ──────────────────────────────────────────

final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return ToolRegistry();
});

final permissionManagerProvider = Provider<PermissionManager>((ref) {
  return PermissionManager();
});

final toolExecutorProvider = Provider<ToolExecutor>((ref) {
  final registry = ref.watch(toolRegistryProvider);
  final timeline = ref.watch(timelineServiceProvider);
  final orb = ref.watch(orbStateManagerProvider);
  return ToolExecutor(
    registry: registry,
    timeline: timeline,
    orb: orb,
  );
});

final nlParserProvider = Provider<NaturalLanguageParser>((ref) {
  return NaturalLanguageParser();
});

final memoryPipelineProvider = Provider<MemoryExtractionPipeline>((ref) {
  final memoryService = ref.watch(memoryServiceProvider);
  final timeline = ref.watch(timelineServiceProvider);
  return MemoryExtractionPipeline(
    memoryService: memoryService,
    timeline: timeline,
  );
});

final desktopFrameworkProvider = Provider<DesktopActionFramework>((ref) {
  final timeline = ref.watch(timelineServiceProvider);
  final orb = ref.watch(orbStateManagerProvider);
  return DesktopActionFramework(
    timeline: timeline,
    orb: orb,
  );
});

// ─── Stream Providers ──────────────────────────────────────────────

final toolExecutionsProvider = StreamProvider.autoDispose((ref) {
  final executor = ref.watch(toolExecutorProvider);
  return executor.executions;
});

final permissionRequestsProvider = StreamProvider.autoDispose((ref) {
  final permissions = ref.watch(permissionManagerProvider);
  return permissions.requests;
});
