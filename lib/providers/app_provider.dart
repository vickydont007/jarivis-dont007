import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ai_engine.dart';
import '../core/memory_system.dart';
import '../core/agent_network.dart';
import '../services/scheduler_service.dart';
import '../services/voice_service.dart';
import '../social/social_manager.dart';
import '../tools/tool_manager.dart';

class AppState {
  final AIEngine? aiEngine;
  final bool isConnected;
  final AIProvider provider;
  final String apiKey;
  final MemorySystem? memory;
  final ToolManager? toolManager;
  final AgentNetwork? agentNetwork;
  final SchedulerService? scheduler;
  final VoiceService? voiceService;
  final SocialManager? socialManager;

  AppState({
    this.aiEngine,
    this.isConnected = false,
    this.provider = AIProvider.openrouter,
    this.apiKey = '',
    this.memory,
    this.toolManager,
    this.agentNetwork,
    this.scheduler,
    this.voiceService,
    this.socialManager,
  });

  AppState copyWith({
    AIEngine? aiEngine,
    bool? isConnected,
    AIProvider? provider,
    String? apiKey,
    MemorySystem? memory,
    ToolManager? toolManager,
    AgentNetwork? agentNetwork,
    SchedulerService? scheduler,
    VoiceService? voiceService,
    SocialManager? socialManager,
  }) {
    return AppState(
      aiEngine: aiEngine ?? this.aiEngine,
      isConnected: isConnected ?? this.isConnected,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      memory: memory ?? this.memory,
      toolManager: toolManager ?? this.toolManager,
      agentNetwork: agentNetwork ?? this.agentNetwork,
      scheduler: scheduler ?? this.scheduler,
      voiceService: voiceService ?? this.voiceService,
      socialManager: socialManager ?? this.socialManager,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AIEngine? _engine;
  MemorySystem? _memory;
  ToolManager? _toolManager;
  AgentNetwork? _agentNetwork;
  SchedulerService? _scheduler;
  VoiceService? _voiceService;
  SocialManager? _socialManager;

  AppStateNotifier() : super(AppState()) {
    _memory = MemorySystem();
    _agentNetwork = AgentNetwork();
    _scheduler = SchedulerService();
    _voiceService = VoiceService();
    _socialManager = SocialManager();

    _toolManager = ToolManager(
      memory: _memory!,
      network: _agentNetwork!,
      scheduler: _scheduler!,
    );
    _toolManager!.initialize();

    _agentNetwork!.initializeDefaultNetwork();

    state = state.copyWith(
      memory: _memory,
      toolManager: _toolManager,
      agentNetwork: _agentNetwork,
      scheduler: _scheduler,
      voiceService: _voiceService,
      socialManager: _socialManager,
    );
  }

  Future<void> initializeAI({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
    String? modelName,
  }) async {
    _engine = _toolManager!.createAIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
    );

    try {
      await _engine!.connect();
      state = state.copyWith(
        aiEngine: _engine,
        isConnected: true,
        provider: provider,
        apiKey: apiKey,
      );
    } catch (e) {
      print('Failed to connect to AI: $e');
      state = state.copyWith(
        aiEngine: _engine,
        isConnected: false,
        provider: provider,
        apiKey: apiKey,
      );
    }
  }

  Future<String> sendMessage(String message, {List<Map<String, dynamic>>? history}) async {
    if (_engine == null) {
      return 'AI Engine not initialized. Please configure in Settings.';
    }

    try {
      final memoryEntry = MemoryEntry.create(
        content: message,
        category: 'chat',
        metadata: {'role': 'user'},
      );
      _memory?.addMemory(memoryEntry);

      if (AIEngine.isImageRequest(message)) {
        final result = await _engine!.generateImage(message);
        if (result['success'] == true) {
          return result['content'] ?? 'Image generated';
        }
        return 'Error: ${result['error']}';
      }

      final result = await _engine!.sendMessageWithTools(
        message,
        history: history,
        onToolCall: (name, args) async {
          return await _toolManager!.executeTool(name, args);
        },
      );

      final response = result['content'] as String? ?? 'No response';
      final toolCalls = result['toolCalls'] as List? ?? [];
      final toolResults = result['toolResults'] as List? ?? [];

      final responseEntry = MemoryEntry.create(
        content: response,
        category: 'chat',
        metadata: {
          'role': 'assistant',
          'tool_calls': toolCalls.length,
          'tool_results': toolResults.length,
        },
      );
      _memory?.addMemory(responseEntry);

      if (toolCalls.isNotEmpty) {
        final toolSummary = toolResults.map((r) {
          final name = r['name'];
          final success = r['success'] == true ? 'OK' : 'FAIL';
          return '[$success] $name';
        }).join('\n');

        return '$response\n\n---\nTools executed:\n$toolSummary';
      }

      return response;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Stream<String> sendMessageStream(String message, {List<Map<String, dynamic>>? history}) async* {
    if (_engine == null) {
      yield 'AI Engine not initialized. Please configure in Settings.';
      return;
    }

    final memoryEntry = MemoryEntry.create(
      content: message,
      category: 'chat',
      metadata: {'role': 'user'},
    );
    _memory?.addMemory(memoryEntry);

    yield* _engine!.sendMessageStream(message, history: history);
  }

  void disconnect() {
    _engine?.disconnect();
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    _engine?.dispose();
    _memory?.dispose();
    _toolManager?.dispose();
    _voiceService?.dispose();
    _socialManager?.dispose();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
