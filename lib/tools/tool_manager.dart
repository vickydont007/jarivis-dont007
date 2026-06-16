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
import 'facebook_tool.dart';
import 'file_manager_tool.dart';
import 'calendar_ai_tools.dart';
import 'email_ai_tools.dart';
import '../social/social_manager.dart';
import '../core/agent_personality.dart';
import '../core/services/calendar_service.dart';
import '../core/services/email_service.dart';

const String toolsPrompt = '''IMPORTANT - FILE PATH RULES:
- You can only access files in the user's home directory: /Users/abc/
- Use paths like: /Users/abc/jarivis-dont007, /Users/abc/Desktop, /Users/abc/Documents
- NEVER try to access system directories like /System, /usr, /bin
- If a file operation fails, try using the home directory path instead

AVAILABLE TOOLS:
- file_list, file_read, file_write, file_delete, file_search, file_copy, file_move: Basic file operations
- file_rename, file_append, file_create_folder, file_get_info, file_search_content, file_search_recursive: Advanced file management
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
- git_status, git_add, git_commit, git_push, git_pull, git_diff, git_log, git_branch, git_checkout, git_merge: Git operations
- email_send, email_list, email_read: Email via macOS Mail app (legacy)
- email_read: Read emails from inbox with filters
- email_search: Search emails by keyword
- email_send: Send an email to a recipient
- email_draft: Save an email draft without sending
- email_reply: Reply to an existing email
- email_forward: Forward an email to another recipient
- email_archive: Archive an email
- email_mark_read: Mark an email as read or unread
- email_get_unread: Get all unread emails
- email_summarize_inbox: Get inbox summary with stats
- calendar_create_event: Create a new calendar event with date, time, location, category
- calendar_update_event: Update an existing calendar event by ID or title
- calendar_delete_event: Delete a calendar event by ID or title
- calendar_list_events: List events for today, tomorrow, week, or a specific date
- calendar_find_free_time: Find free time slots on a given date
- calendar_get_today: Get today's full agenda
- calendar_get_week: Get this week's calendar events
- calendar_search_events: Search events by keyword in title, description, or location
- db_connect, db_query, db_list_tables, db_disconnect, db_info: SQLite database operations
- clipboard_get, clipboard_set, clipboard_history, clipboard_clear: Clipboard operations
- export_chat_md, export_chat_json: Export chat history
- facebook_post, facebook_read_posts, facebook_page_info: Facebook Page posting and management

CRITICAL TOOL RULES:
- Tool names must be EXACTLY as listed above. Never add extra characters like <, >, |, or text after the tool name
- Example CORRECT: calendar_create with params {title: "Meeting", date: "2026-06-20", time: "10:00"}
- Example WRONG: calendar_create<|channel|>commentary (THIS IS INVALID)

CALENDAR DATE FORMAT:
- Date MUST be YYYY-MM-DD format (e.g., "2026-06-20" for 20 June 2026)
- Time MUST be HH:MM in 24-hour format (e.g., "10:00" for 10 AM, "14:30" for 2:30 PM)
- Example: calendar_create_event(title: "Team Meeting", date: "2026-06-20", time: "10:00")

CALENDAR & EMAIL CAPABILITIES:
- You CAN read emails using: email_read (with count/unreadOnly/folder params)
- You CAN search emails using: email_search
- You CAN send emails using: email_send
- You CAN draft emails using: email_draft
- You CAN reply to emails using: email_reply
- You CAN forward emails using: email_forward
- You CAN archive emails using: email_archive
- You CAN mark emails read/unread using: email_mark_read
- You CAN get unread emails using: email_get_unread
- You CAN summarize inbox using: email_summarize_inbox
- You CAN list calendar events using: calendar_list_events
- You CAN create calendar events using: calendar_create_event
- You CAN update calendar events using: calendar_update_event
- You CAN delete calendar events using: calendar_delete_event
- You CAN find free time using: calendar_find_free_time
- You CAN get today's agenda using: calendar_get_today
- You CAN get this week's events using: calendar_get_week
- You CAN search events using: calendar_search_events

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
11. NEVER say "I cannot" or "I don't have access" if the tool exists in the AVAILABLE TOOLS list. Always try the tool first.

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
  SocialManager? _socialManager;
  CalendarService? _calendarService;
  EmailService? _emailService;

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
    CalendarService? calendarService,
    EmailService? emailService,
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
        _calendarService = calendarService,
        _emailService = emailService,
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
      _ragManager!.initialize(); // fire-and-forget async
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
    _registry.registerAll(getAllFileManagerTools());
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
    // New calendar AI tools
    if (_calendarService != null) {
      _registry.registerAll(getAllCalendarAITools(_calendarService!));
    }
    // New email AI tools
    if (_emailService != null) {
      _registry.registerAll(getAllEmailAITools(_emailService!));
    }
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
  String get systemPromptText => toolsPrompt;

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

  void setSocialManager(SocialManager socialManager) {
    _socialManager = socialManager;
    if (_socialManager != null) {
      _registry.registerAll(getAllFacebookTools(_socialManager!));
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
    AgentPersonality? personality,
    String? emotionContext,
    String? relationshipContext,
    String? memoryContext,
  }) {
    setApiKey(apiKey);

    final fullSystemPrompt = personality != null
        ? personality.getSystemPrompt(toolsPrompt, emotionContext: emotionContext, relationshipContext: relationshipContext, memoryContext: memoryContext)
        : AgentPersonality().getSystemPrompt(toolsPrompt, emotionContext: emotionContext, relationshipContext: relationshipContext, memoryContext: memoryContext);

    return AIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
      systemPrompt: fullSystemPrompt,
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
