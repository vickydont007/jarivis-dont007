import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ai_engine.dart';
import '../core/agent_personality.dart';
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
import '../core/agent_orchestrator.dart';
import '../core/memory_evolution.dart';
import '../core/emotion_detector.dart';
import '../core/girlfriend_memory.dart';
import '../core/conversation_manager.dart';
import '../core/services/orb_state_manager.dart';
import '../core/services/timeline_service.dart';
import '../core/services/agent_manager.dart';
import '../core/services/memory_service.dart';
import '../core/services/persistent_scheduler.dart';
import '../core/services/daily_briefing_service.dart';
import '../core/services/agent_collaboration.dart';
import '../core/services/memory_search.dart';
import '../core/capabilities/permission_manager.dart';
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
  final AgentOrchestrator? agentOrchestrator;
  final PermissionManager? permissionManager;
  final PersistentScheduler? persistentScheduler;
  final DailyBriefingService? dailyBriefingService;
  final AgentCollaboration? agentCollaboration;
  final MemorySearch? memorySearch;
  final TimelineService? timelineService;
  final AgentManager? agentManager;
  final MemoryService? memoryService;

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
    this.agentOrchestrator,
    this.permissionManager,
    this.persistentScheduler,
    this.dailyBriefingService,
    this.agentCollaboration,
    this.memorySearch,
    this.timelineService,
    this.agentManager,
    this.memoryService,
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
    AgentOrchestrator? agentOrchestrator,
    PermissionManager? permissionManager,
    PersistentScheduler? persistentScheduler,
    DailyBriefingService? dailyBriefingService,
    AgentCollaboration? agentCollaboration,
    MemorySearch? memorySearch,
    TimelineService? timelineService,
    AgentManager? agentManager,
    MemoryService? memoryService,
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
      agentOrchestrator: agentOrchestrator ?? this.agentOrchestrator,
      permissionManager: permissionManager ?? this.permissionManager,
      persistentScheduler: persistentScheduler ?? this.persistentScheduler,
      dailyBriefingService: dailyBriefingService ?? this.dailyBriefingService,
      agentCollaboration: agentCollaboration ?? this.agentCollaboration,
      memorySearch: memorySearch ?? this.memorySearch,
      timelineService: timelineService ?? this.timelineService,
      agentManager: agentManager ?? this.agentManager,
      memoryService: memoryService ?? this.memoryService,
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
  AgentOrchestrator? _agentOrchestrator;
  MemoryEvolution? _memoryEvolution;
  ConversationManager? _conversationManager;
  
  // Phase 5 services
  PermissionManager? _permissionManager;
  PersistentScheduler? _persistentScheduler;
  MemorySearch? _memorySearch;
  
  // Core services wired to AppState
  TimelineService? _timelineService;
  AgentManager? _agentManager;
  MemoryService? _memoryService;

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
    _agentOrchestrator = AgentOrchestrator();
    _memoryEvolution = MemoryEvolution();
    _conversationManager = ConversationManager(_engine);
    
    // Phase 5: Initialize autonomous systems
    _permissionManager = PermissionManager();
    _persistentScheduler = PersistentScheduler();
    _memorySearch = MemorySearch();

    // Core services wired to AppState (single source of truth)
    final orb = OrbStateManager();
    _timelineService = TimelineService();
    _agentManager = AgentManager(
      agentRepository: AgentRepositoryAdapter(_agentNetwork!),
      taskRepository: TaskRepositoryEmpty(),
      timeline: _timelineService!,
      orb: orb,
    );
    _memoryService = MemoryService(
      repository: MemoryRepositoryAdapter(_memory!),
      timeline: _timelineService!,
    );

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
    _toolManager!.setSocialManager(_socialManager!);

    // Wire orchestrator to AI engine and tools
    if (_engine != null && _toolManager != null) {
      _agentOrchestrator!.setEngine(_engine!, _toolManager!);
    }

    _agentNetwork!.initializeDefaultNetwork();
    
    // Initialize voice service
    _voiceService!.initialize();
    
    // Phase 5: Initialize autonomous systems
    _permissionManager!.initialize();
    _persistentScheduler!.initialize();

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
      agentOrchestrator: _agentOrchestrator,
      permissionManager: _permissionManager,
      persistentScheduler: _persistentScheduler,
      memorySearch: _memorySearch,
      timelineService: _timelineService,
      agentManager: _agentManager,
      memoryService: _memoryService,
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

      // Restore social media connections from SharedPreferences
      await _restoreSocialConnections();

      // Force rebuild so widgets see updated social status
      state = state.copyWith(socialManager: _socialManager);
    } catch (e) {
      print('Failed to load saved state: $e');
    }
  }

  Future<void> _restoreSocialConnections() async {
    final prefs = await SharedPreferences.getInstance();

    final fbToken = prefs.getString('facebook_access_token') ?? '';
    final fbPageId = prefs.getString('facebook_page_id') ?? '';
    if (fbToken.isNotEmpty && fbPageId.isNotEmpty) {
      _socialManager?.setupFacebook(accessToken: fbToken, pageId: fbPageId);
      print('Facebook restored: pageId=$fbPageId');
    }

    final igToken = prefs.getString('instagram_access_token') ?? '';
    final igPageId = prefs.getString('instagram_page_id') ?? '';
    if (igToken.isNotEmpty && igPageId.isNotEmpty) {
      _socialManager?.setupInstagram(accessToken: igToken, pageId: igPageId);
      print('Instagram restored: pageId=$igPageId');
    }

    final waToken = prefs.getString('whatsapp_access_token') ?? '';
    final waPhoneId = prefs.getString('whatsapp_phone_number_id') ?? '';
    final waBizId = prefs.getString('whatsapp_business_account_id') ?? '';
    if (waToken.isNotEmpty && waPhoneId.isNotEmpty && waBizId.isNotEmpty) {
      _socialManager?.setupWhatsApp(accessToken: waToken, phoneNumberId: waPhoneId, businessAccountId: waBizId);
      print('WhatsApp restored: phoneId=$waPhoneId');
    }

    final tgToken = prefs.getString('telegram_bot_token') ?? '';
    if (tgToken.isNotEmpty) {
      _socialManager?.setupTelegram(tgToken);
      print('Telegram restored');
    }

    final dcToken = prefs.getString('discord_bot_token') ?? '';
    if (dcToken.isNotEmpty) {
      _socialManager?.setupDiscord(dcToken);
      print('Discord restored');
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
    final personality = await AgentPersonality.load();
    await GirlfriendMemory.init();
    await _memoryEvolution!.database;

    _engine = _toolManager!.createAIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
      personality: personality,
    );

    _conversationManager = ConversationManager(_engine);

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

  Future<String> sendMessage(String message, {List<Map<String, dynamic>>? history, CancelToken? cancelToken}) async {
    if (_engine == null) {
      return 'AI Engine not initialized. Please configure in Settings.';
    }

    // Detect emotion from user message
    final emotionResult = EmotionDetector.detect(message);
    
    // Save emotion to memory evolution
    await _memoryEvolution!.recordEmotion(
      emotion: emotionResult.emotion,
      confidence: emotionResult.confidence,
      intensity: emotionResult.intensity,
      context: message,
      triggers: emotionResult.triggers,
    );

    // Auto-extract facts from message for girlfriend memory
    await GirlfriendMemory.autoExtractFromMessage(message);
    await GirlfriendMemory.rememberDailyUpdate(message);
    await GirlfriendMemory.recordFirstConversation();

    // Get emotion and relationship context for AI
    final emotionContext = await _memoryEvolution!.getCurrentMoodContext();
    final relationshipContext = GirlfriendMemory.getRelationshipContext();

    // Recreate engine with updated emotion context
    final personality = await AgentPersonality.load();
    _engine = _toolManager!.createAIEngine(
      provider: state.provider,
      apiKey: state.apiKey,
      personality: personality,
      emotionContext: emotionContext,
      relationshipContext: relationshipContext,
    );

    // Check if orchestrator should handle this as a delegated task
    final shouldDelegate = _agentOrchestrator != null && _shouldDelegateToAgent(message);
    
    if (shouldDelegate) {
      final delegatedResponse = await _agentOrchestrator!.delegateTask(message);
      if (delegatedResponse.isNotEmpty) {
        final memoryEntry = MemoryEntry.create(
          content: message,
          category: 'chat',
          metadata: {'role': 'user'},
        );
        _memory?.addMemory(memoryEntry);
        
        final responseEntry = MemoryEntry.create(
          content: delegatedResponse,
          category: 'chat',
          metadata: {'role': 'assistant', 'delegated': true},
        );
        _memory?.addMemory(responseEntry);
        
        await _memoryEvolution!.recordInteraction(
          userMessage: message,
          aiResponse: delegatedResponse,
          emotion: emotionResult.emotion,
          emotionConfidence: emotionResult.confidence,
        );
        
        return delegatedResponse;
      }
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

      var enrichedMessage = message;
      try {
        final ragContext = await _toolManager?.ragManager?.getRelevantContext(message);
        if (ragContext != null && ragContext.isNotEmpty) {
          enrichedMessage = '$ragContext\n\nUser message: $message';
        }
      } catch (e) {}

      final result = await _engine!.sendMessageWithTools(
        enrichedMessage,
        history: history,
        cancelToken: cancelToken,
        onToolCall: (name, args) async {
          return await _toolManager!.executeTool(name, args);
        },
      );

      final success = result['success'] as bool? ?? false;
      var response = result['content'] as String? ?? '';
      final toolCalls = result['toolCalls'] as List? ?? [];
      final toolResults = result['toolResults'] as List? ?? [];

      if (response.isEmpty && toolCalls.isNotEmpty) {
        final toolSummary = toolResults.map((r) {
          final name = r['name'];
          final content = r['result'] as String? ?? '';
          final status = r['success'] == true ? '✓' : '✗';
          return '$status $name: ${content.length > 200 ? content.substring(0, 200) + "..." : content}';
        }).join('\n');
        response = 'Tools executed:\n$toolSummary';
      } else if (response.isEmpty && !success) {
        response = result['error'] as String? ?? 'AI did not return a response. Please try again.';
      } else if (response.isEmpty) {
        response = 'I received your message but could not generate a response. Please try again.';
      }

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

      // Record interaction with emotion
      await _memoryEvolution!.recordInteraction(
        userMessage: message,
        aiResponse: response,
        toolsUsed: toolCalls.map((t) => t.toString()).toList(),
        emotion: emotionResult.emotion,
        emotionConfidence: emotionResult.confidence,
      );

      // Track girlfriend memory
      final shortResponse = response.length > 50 ? response.substring(0, 50) : response;
      await GirlfriendMemory.rememberSharedExperience('User said: $message, AI responded with: $shortResponse...');

      // Add to conversation manager
      await _conversationManager!.addMessage('user', message);
      await _conversationManager!.addMessage('assistant', response);

      return response;
    } catch (e) {
      return 'Error: $e';
    }
  }

  bool _shouldDelegateToAgent(String message) {
    // Delegate if message contains task-like keywords
    final taskKeywords = [
      'schedule', 'remind', 'create', 'write', 'analyze', 'search', 'find',
      'build', 'run', 'execute', 'automate', 'organize', 'backup', 'sync',
      'post', 'send', 'message', 'email', 'meeting', 'record', 'summarize',
      'convert', 'translate', 'fetch', 'download', 'upload', 'monitor',
    ];
    final lower = message.toLowerCase();
    return taskKeywords.any((k) => lower.contains(k));
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
    _timelineService?.dispose();
    _agentManager?.dispose();
    _memoryService?.dispose();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
