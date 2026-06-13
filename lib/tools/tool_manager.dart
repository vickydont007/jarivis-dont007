import 'dart:async';
import '../core/ai_engine.dart';
import '../core/memory_system.dart';
import '../core/agent_network.dart';
import '../core/context_memory.dart';
import '../core/screen_context.dart';
import '../core/cross_app_bridge.dart';
import '../core/predictive_automation.dart';
import '../core/screen_recording.dart';
import '../core/meeting_assistant.dart';
import '../core/notification_intelligence.dart';
import '../core/file_converter.dart';
import '../core/rag/rag_manager.dart';
import '../core/code_sandbox.dart';
import '../core/agent_learning.dart';
import '../core/real_time_monitor.dart';
import '../core/cost_tracker.dart';
import '../core/multi_modal.dart';
import '../core/web_automation.dart';
import '../core/agent_communication.dart';
import '../services/scheduler_service.dart';
import 'tool.dart';
import 'tool_registry.dart';
import 'tool_executor.dart';
import 'file_tool.dart';
import 'system_tool.dart';
import 'shell_tool.dart';
import 'weather_tool.dart';
import 'memory_tool.dart';
import 'web_tool.dart';
import 'scheduler_tool.dart';
import 'agent_tool.dart';
import 'code_tool.dart';
import 'multi_modal_tool.dart';
import 'context_memory_tool.dart';
import 'screen_context_tool.dart';
import 'cross_app_tool.dart';
import 'predictive_tool.dart';
import 'recording_tool.dart';
import 'meeting_tool.dart';
import 'notification_tool.dart';
import 'converter_tool.dart';
import 'git_tool.dart';
import 'email_tool.dart';
import 'calendar_tool.dart';
import 'database_tool.dart';
import 'clipboard_tool.dart';
import 'export_tool.dart';

const String systemPrompt = '''You are Nextron, a powerful AI desktop assistant. You have access to various tools to help users with their tasks.

IMPORTANT - FILE PATH RULES:
- You can only access files in the user's home directory: /Users/abc/
- Use paths like: /Users/abc/jarivis-dont007, /Users/abc/Desktop, /Users/abc/Documents
- NEVER try to access system directories like /System, /usr, /bin
- If a file operation fails, try using the home directory path instead

AVAILABLE TOOLS:
- file_list, file_read, file_write, file_delete, file_search, file_copy, file_move: File operations
- shell_exec: Execute terminal commands
- system_info, system_shutdown, system_restart, system_sleep, system_lock, system_open_app, system_open_url: System control
- weather_current, weather_forecast: Weather information
- memory_search, memory_semantic_search, memory_add, memory_list, memory_delete: Memory/knowledge management
- context_set, context_get, context_search, context_category, context_delete, context_stats: Long-term context memory
- web_fetch, web_search, web_fetch_page, web_get_links, web_open_url: Web access and browsing
- scheduler_create, scheduler_list, scheduler_cancel: Task scheduling
- agent_spawn, agent_kill, agent_status: Agent management
- code_execute: Execute Python or JavaScript code safely
- image_analyze, image_analyze_url: Understand images and their content
- screen_capture, screen_capture_ocr, accessibility_info, active_app, running_apps: Screen context awareness
- check_app_installed, open_app, send_cross_app_message, get_app_info, get_installed_apps, send_clipboard, get_clipboard: Cross-app integration
- create_automation_pattern, get_patterns_by_trigger, get_all_patterns, record_automation_event, update_pattern_confidence, delete_automation_pattern, get_automation_stats: Predictive automation
- start_recording, stop_recording, pause_recording, resume_recording, recording_status: Screen recording
- start_meeting, end_meeting, add_meeting_note, get_meeting_notes, get_meetings, update_meeting_summary, delete_meeting: Meeting assistant
- create_notification_rule, get_notification_rules, record_notification_event, toggle_notification_rule, delete_notification_rule, get_recent_notifications, get_notification_stats: Notification intelligence
- convert_file, get_supported_formats, check_format_supported: File conversion

RULES:
1. Always use tools when the user asks you to perform actions
2. Be careful with destructive operations (delete, shutdown) - confirm first
3. For file operations, always use /Users/abc/ prefix for paths
4. For system commands, explain what you're about to do
5. If a tool fails, explain the error and suggest alternatives
6. You can chain multiple tool calls in sequence
7. Respond in the same language the user uses (English or Hindi)
8. Always generate a text response after executing tools - summarize what you did
9. Use context tools to remember user preferences, facts, and important details across sessions
10. Use screen context tools to understand what's on the user's screen

CRITICAL - LIVE DATA:
- ALWAYS use web_search when the user asks about current events, news, live data, prices, scores, weather, or any real-time information
- Use web_fetch to read full content from a specific URL
- NEVER make up current data - search the internet first
- Examples that REQUIRE web_search: "current price of...", "today's news", "latest score", "what's happening in...", "current weather in..."
''';

class ToolManager {
  final ToolRegistry _registry;
  late final ToolExecutor _executor;
  final MemorySystem _memory;
  final AgentNetwork _network;
  final SchedulerService _scheduler;
  final ContextMemory _contextMemory;
  final ScreenContext _screenContext;
  final CrossAppBridge _crossAppBridge;
  final PredictiveAutomation _predictiveAutomation;
  final ScreenRecording _screenRecording;
  final MeetingAssistant _meetingAssistant;
  final NotificationIntelligence _notificationIntelligence;
  final FileConverter _fileConverter;
  final CodeExecutionSandbox _codeSandbox;
  final AgentLearning _agentLearning;
  final RealTimeMonitor _monitor;
  final CostTracker _costTracker;
  final MultiModalSupport _multiModal;
  final WebAutomation _webAutomation;
  final AgentCommunication _agentCommunication;
  RAGManager? _ragManager;

  ToolManager({
    required MemorySystem memory,
    required AgentNetwork network,
    required SchedulerService scheduler,
    required ContextMemory contextMemory,
    required ScreenContext screenContext,
    required CrossAppBridge crossAppBridge,
    required PredictiveAutomation predictiveAutomation,
    required ScreenRecording screenRecording,
    required MeetingAssistant meetingAssistant,
    required NotificationIntelligence notificationIntelligence,
    required FileConverter fileConverter,
  })  : _memory = memory,
        _network = network,
        _scheduler = scheduler,
        _contextMemory = contextMemory,
        _screenContext = screenContext,
        _crossAppBridge = crossAppBridge,
        _predictiveAutomation = predictiveAutomation,
        _screenRecording = screenRecording,
        _meetingAssistant = meetingAssistant,
        _notificationIntelligence = notificationIntelligence,
        _fileConverter = fileConverter,
        _codeSandbox = CodeExecutionSandbox(),
        _agentLearning = AgentLearning(),
        _monitor = RealTimeMonitor(),
        _costTracker = CostTracker(),
        _multiModal = MultiModalSupport(),
        _webAutomation = WebAutomation(),
        _agentCommunication = AgentCommunication(),
        _registry = ToolRegistry();

  void initialize({String? apiKey}) {
    if (apiKey != null && apiKey.isNotEmpty) {
      _ragManager = RAGManager(
        apiKey: apiKey,
        memorySystem: _memory,
      );
      _multiModal.setApiKey(apiKey);
    }
    _registerTools();
    _executor = ToolExecutor(
      registry: _registry,
      defaultTimeout: const Duration(seconds: 30),
    );
    _monitor.logSystemEvent('ToolManager initialized with ${_registry.count} tools');
  }

  void _registerTools() {
    _registry.registerAll(getAllFileTools());
    _registry.registerAll(getAllSystemTools());
    _registry.registerAll(getAllShellTools());
    _registry.registerAll(getAllWeatherTools());
    _registry.registerAll(getAllMemoryTools(_memory, ragManager: _ragManager));
    _registry.registerAll(getAllContextMemoryTools(_contextMemory));
    _registry.registerAll(getAllScreenContextTools(_screenContext));
    _registry.registerAll(getAllCrossAppTools(_crossAppBridge));
    _registry.registerAll(getAllPredictiveTools(_predictiveAutomation));
    _registry.registerAll(getAllRecordingTools(_screenRecording));
    _registry.registerAll(getAllMeetingTools(_meetingAssistant));
    _registry.registerAll(getAllNotificationTools(_notificationIntelligence));
    _registry.registerAll(getAllConverterTools(_fileConverter));
    _registry.registerAll(getAllWebTools());
    _registry.registerAll(getAllSchedulerTools(_scheduler));
    _registry.registerAll(getAllAgentTools(_network));
    _registry.registerAll(getAllCodeTools(_codeSandbox));
    _registry.registerAll(getAllMultiModalTools(_multiModal));
    _registry.registerAll(getAllWebAutomationTools(_webAutomation));
    // New tools
    _registry.registerAll(getAllGitTools());
    _registry.registerAll(getAllEmailTools());
    _registry.registerAll(getAllCalendarTools());
    _registry.registerAll(getAllDatabaseTools());
    _registry.registerAll(getAllClipboardTools());
    _registry.registerAll(getAllExportTools());
  }

  ToolRegistry get registry => _registry;
  ToolExecutor get executor => _executor;
  RAGManager? get ragManager => _ragManager;
  CodeExecutionSandbox get codeSandbox => _codeSandbox;
  AgentLearning get agentLearning => _agentLearning;
  RealTimeMonitor get monitor => _monitor;
  CostTracker get costTracker => _costTracker;
  MultiModalSupport get multiModal => _multiModal;
  WebAutomation get webAutomation => _webAutomation;
  AgentCommunication get agentCommunication => _agentCommunication;
  ContextMemory get contextMemory => _contextMemory;
  String get systemPromptText => systemPrompt;

  void setApiKey(String apiKey) {
    if (apiKey.isNotEmpty) {
      _ragManager ??= RAGManager(
        apiKey: apiKey,
        memorySystem: _memory,
      );
      _ragManager!.setApiKey(apiKey);
      _multiModal.setApiKey(apiKey);
    }
  }

  List<Map<String, dynamic>> getToolDefinitions() {
    return _registry.getToolDefinitions();
  }

  Future<ToolResult> executeTool(String name, Map<String, dynamic> params) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _executor.execute(name, params);
      stopwatch.stop();
      _monitor.logToolCall(name, params, result.success);
      return result;
    } catch (e) {
      stopwatch.stop();
      _monitor.logToolCall(name, params, false);
      rethrow;
    }
  }

  AIEngine createAIEngine({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
    String? modelName,
  }) {
    setApiKey(apiKey);

    return AIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
      systemPrompt: systemPrompt,
      toolDefinitions: getToolDefinitions(),
    );
  }

  void dispose() {
    _executor.dispose();
    _ragManager?.dispose();
    _agentLearning.dispose();
    _monitor.dispose();
    _costTracker.dispose();
    _agentCommunication.dispose();
  }
}
