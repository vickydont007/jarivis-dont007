import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ai_engine.dart';
import '../core/memory_system.dart';
import '../core/agent_network.dart';
import '../core/context_memory.dart';
import '../core/app_state_persistence.dart';
import '../core/screen_context.dart';
import '../core/cross_app_bridge.dart';
import '../core/predictive_automation.dart';
import '../core/screen_recording.dart';
import '../core/meeting_assistant.dart';
import '../core/notification_intelligence.dart';
import '../core/file_converter.dart';
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
  final ContextMemory? contextMemory;
  final AppStatePersistence? persistence;
  final ScreenContext? screenContext;
  final CrossAppBridge? crossAppBridge;
  final PredictiveAutomation? predictiveAutomation;
  final ScreenRecording? screenRecording;
  final MeetingAssistant? meetingAssistant;
  final NotificationIntelligence? notificationIntelligence;
  final FileConverter? fileConverter;

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
    this.contextMemory,
    this.persistence,
    this.screenContext,
    this.crossAppBridge,
    this.predictiveAutomation,
    this.screenRecording,
    this.meetingAssistant,
    this.notificationIntelligence,
    this.fileConverter,
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
    ContextMemory? contextMemory,
    AppStatePersistence? persistence,
    ScreenContext? screenContext,
    CrossAppBridge? crossAppBridge,
    PredictiveAutomation? predictiveAutomation,
    ScreenRecording? screenRecording,
    MeetingAssistant? meetingAssistant,
    NotificationIntelligence? notificationIntelligence,
    FileConverter? fileConverter,
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
      contextMemory: contextMemory ?? this.contextMemory,
      persistence: persistence ?? this.persistence,
      screenContext: screenContext ?? this.screenContext,
      crossAppBridge: crossAppBridge ?? this.crossAppBridge,
      predictiveAutomation: predictiveAutomation ?? this.predictiveAutomation,
      screenRecording: screenRecording ?? this.screenRecording,
      meetingAssistant: meetingAssistant ?? this.meetingAssistant,
      notificationIntelligence: notificationIntelligence ?? this.notificationIntelligence,
      fileConverter: fileConverter ?? this.fileConverter,
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
  ContextMemory? _contextMemory;
  AppStatePersistence? _persistence;
  ScreenContext? _screenContext;
  CrossAppBridge? _crossAppBridge;
  PredictiveAutomation? _predictiveAutomation;
  ScreenRecording? _screenRecording;
  MeetingAssistant? _meetingAssistant;
  NotificationIntelligence? _notificationIntelligence;
  FileConverter? _fileConverter;

  AppStateNotifier() : super(AppState()) {
    _memory = MemorySystem();
    _agentNetwork = AgentNetwork();
    _scheduler = SchedulerService();
    _voiceService = VoiceService();
    _socialManager = SocialManager();
    _contextMemory = ContextMemory();
    _persistence = AppStatePersistence();
    _screenContext = ScreenContext();
    _crossAppBridge = CrossAppBridge();
    _predictiveAutomation = PredictiveAutomation();
    _screenRecording = ScreenRecording();
    _meetingAssistant = MeetingAssistant();
    _notificationIntelligence = NotificationIntelligence();
    _fileConverter = FileConverter();

    _toolManager = ToolManager(
      memory: _memory!,
      network: _agentNetwork!,
      scheduler: _scheduler!,
      contextMemory: _contextMemory!,
      screenContext: _screenContext!,
      crossAppBridge: _crossAppBridge!,
      predictiveAutomation: _predictiveAutomation!,
      screenRecording: _screenRecording!,
      meetingAssistant: _meetingAssistant!,
      notificationIntelligence: _notificationIntelligence!,
      fileConverter: _fileConverter!,
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
      contextMemory: _contextMemory,
      persistence: _persistence,
      screenContext: _screenContext,
      crossAppBridge: _crossAppBridge,
      predictiveAutomation: _predictiveAutomation,
      screenRecording: _screenRecording,
      meetingAssistant: _meetingAssistant,
      notificationIntelligence: _notificationIntelligence,
      fileConverter: _fileConverter,
    );

    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final savedProvider = await _persistence!.loadSetting<String>('provider');
      final savedApiKey = await _persistence!.loadSetting<String>('apiKey');
      final savedModel = await _persistence!.loadSetting<String>('selectedModel');

      if (savedProvider != null && savedApiKey != null && savedApiKey.isNotEmpty) {
        final provider = AIProvider.values.firstWhere(
          (p) => p.name == savedProvider,
          orElse: () => AIProvider.openrouter,
        );
        await initializeAI(
          provider: provider,
          apiKey: savedApiKey,
          modelName: savedModel,
        );
      }
    } catch (e) {
      print('Failed to load saved state: $e');
    }
  }

  Future<void> saveState() async {
    try {
      await _persistence!.saveSetting('provider', state.provider.name);
      await _persistence!.saveSetting('apiKey', state.apiKey);
      await _persistence!.saveSetting('isConnected', state.isConnected);
    } catch (e) {
      print('Failed to save state: $e');
    }
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
      await _persistence!.saveSetting('provider', provider.name);
      await _persistence!.saveSetting('apiKey', apiKey);
      if (modelName != null) {
        await _persistence!.saveSetting('selectedModel', modelName);
      }
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
    _contextMemory?.dispose();
    _persistence?.dispose();
    _screenContext?.dispose();
    _crossAppBridge?.dispose();
    _predictiveAutomation?.dispose();
    _screenRecording?.dispose();
    _meetingAssistant?.dispose();
    _notificationIntelligence?.dispose();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
