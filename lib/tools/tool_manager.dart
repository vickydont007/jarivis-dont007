import 'dart:async';
import '../core/ai_engine.dart';
import '../core/memory_system.dart';
import '../core/agent_network.dart';
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

const String systemPrompt = '''You are Nextron, a powerful AI desktop assistant. You have access to various tools to help users with their tasks.

AVAILABLE TOOLS:
- file_list, file_read, file_write, file_delete, file_search, file_copy, file_move: File operations
- shell_exec: Execute terminal commands
- system_info, system_shutdown, system_restart, system_sleep, system_lock, system_open_app, system_open_url: System control
- weather_current, weather_forecast: Weather information
- memory_search, memory_semantic_search, memory_add, memory_list, memory_delete: Memory/knowledge management
- web_fetch, web_search, web_fetch_page, web_get_links, web_open_url: Web access and browsing
- scheduler_create, scheduler_list, scheduler_cancel: Task scheduling
- agent_spawn, agent_kill, agent_status: Agent management
- code_execute: Execute Python or JavaScript code safely
- image_analyze, image_analyze_url: Understand images and their content

RULES:
1. Always use tools when the user asks you to perform actions
2. Be careful with destructive operations (delete, shutdown) - confirm first
3. For file operations, always specify full paths
4. For system commands, explain what you're about to do
5. If a tool fails, explain the error and suggest alternatives
6. You can chain multiple tool calls in sequence
7. Respond in the same language the user uses (English or Hindi)
8. Use memory_semantic_search when you need to find memories by meaning, not just keywords
9. Use code_execute to run Python or JavaScript code for calculations or data processing
10. Use image_analyze to understand what's in images
11. Use web_fetch_page to get full page content, web_get_links to extract links
''';

class ToolManager {
  final ToolRegistry _registry;
  late final ToolExecutor _executor;
  final MemorySystem _memory;
  final AgentNetwork _network;
  final SchedulerService _scheduler;
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
  })  : _memory = memory,
        _network = network,
        _scheduler = scheduler,
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
    _registry.registerAll(getAllWebTools());
    _registry.registerAll(getAllSchedulerTools(_scheduler));
    _registry.registerAll(getAllAgentTools(_network));
    _registry.registerAll(getAllCodeTools(_codeSandbox));
    _registry.registerAll(getAllMultiModalTools(_multiModal));
    _registry.registerAll(getAllWebAutomationTools(_webAutomation));
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
