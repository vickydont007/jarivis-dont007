class AgentCapability {
  final String name;
  final String description;
  final List<String> toolNames;
  final List<String> keywords;

  const AgentCapability({
    required this.name,
    required this.description,
    this.toolNames = const [],
    this.keywords = const [],
  });
}

class RegisteredAgent {
  final String type;
  final String name;
  final String description;
  final String icon;
  final List<AgentCapability> capabilities;
  final bool isActive;
  final int maxConcurrentTasks;

  const RegisteredAgent({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.capabilities = const [],
    this.isActive = true,
    this.maxConcurrentTasks = 3,
  });

  List<String> get allToolNames {
    return capabilities.expand((c) => c.toolNames).toList();
  }

  List<String> get allKeywords {
    return capabilities.expand((c) => c.keywords).toList();
  }

  bool canHandle(String toolName) => allToolNames.contains(toolName);

  bool matchesGoal(String goal) {
    final lower = goal.toLowerCase();
    return allKeywords.any((kw) => lower.contains(kw));
  }
}

class AgentRegistry {
  final List<RegisteredAgent> _agents = [];

  List<RegisteredAgent> get agents => List.unmodifiable(_agents);

  AgentRegistry() {
    _registerDefaultAgents();
  }

  void _registerDefaultAgents() {
    _agents.addAll([
      const RegisteredAgent(
        type: 'memory',
        name: 'Memory Agent',
        description: 'Recall, save, and consolidate memories',
        icon: '🧠',
        capabilities: [
          AgentCapability(
            name: 'memory_operations',
            description: 'Search, save, and manage memories',
            toolNames: ['memory_search', 'memory_add', 'memory_list', 'memory_delete', 'memory_semantic_search'],
            keywords: ['remember', 'memory', 'recall', 'forget', 'recall what', 'learned'],
          ),
          AgentCapability(
            name: 'memory_consolidation',
            description: 'Consolidate and organize memories',
            toolNames: ['memory_consolidate'],
            keywords: ['consolidate', 'organize memories', 'summarize memories'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'research',
        name: 'Research Agent',
        description: 'Search the web, research topics, generate reports',
        icon: '🔬',
        capabilities: [
          AgentCapability(
            name: 'web_search',
            description: 'Search the web and read pages',
            toolNames: ['browser_search', 'browser_open_url', 'browser_extract_content', 'browser_summarize_page', 'web_search', 'web_fetch'],
            keywords: ['search', 'research', 'find', 'look up', 'google', 'web', 'online', 'internet'],
          ),
          AgentCapability(
            name: 'deep_research',
            description: 'In-depth topic, company, and market research',
            toolNames: ['research_topic', 'research_company', 'research_competitors', 'research_market', 'research_trends', 'research_generate_report'],
            keywords: ['research', 'analyze', 'competitors', 'market', 'company', 'industry', 'trends', 'report'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'file',
        name: 'File Agent',
        description: 'Create, read, update, and organize files',
        icon: '📁',
        capabilities: [
          AgentCapability(
            name: 'file_operations',
            description: 'Basic file operations',
            toolNames: ['file_list', 'file_read', 'file_write', 'file_delete', 'file_search', 'file_copy', 'file_move'],
            keywords: ['file', 'folder', 'create', 'save', 'write', 'read', 'delete', 'copy', 'move', 'organize'],
          ),
          AgentCapability(
            name: 'advanced_file_operations',
            description: 'Advanced file management',
            toolNames: ['file_rename', 'file_append', 'file_create_folder', 'file_get_info', 'file_search_content', 'file_search_recursive'],
            keywords: ['rename', 'append', 'mkdir', 'info', 'search content', 'find in files'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'email',
        name: 'Email Agent',
        description: 'Read, send, draft, and manage emails',
        icon: '📧',
        capabilities: [
          AgentCapability(
            name: 'email_operations',
            description: 'Full email management',
            toolNames: ['email_read', 'email_search', 'email_send', 'email_draft', 'email_reply', 'email_forward', 'email_archive', 'email_mark_read', 'email_get_unread', 'email_summarize_inbox'],
            keywords: ['email', 'mail', 'inbox', 'send', 'draft', 'reply', 'forward', 'archive', 'unread'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'calendar',
        name: 'Calendar Agent',
        description: 'Manage events, reminders, and schedules',
        icon: '📅',
        capabilities: [
          AgentCapability(
            name: 'calendar_operations',
            description: 'Full calendar management',
            toolNames: ['calendar_create_event', 'calendar_update_event', 'calendar_delete_event', 'calendar_list_events', 'calendar_find_free_time', 'calendar_get_today', 'calendar_get_week', 'calendar_search_events'],
            keywords: ['calendar', 'event', 'meeting', 'schedule', 'appointment', 'reminder', 'tomorrow', 'today', 'week'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'voice',
        name: 'Voice Agent',
        description: 'Speech input/output and voice interactions',
        icon: '🎙️',
        capabilities: [
          AgentCapability(
            name: 'voice_operations',
            description: 'Speech-to-text and text-to-speech',
            toolNames: [],
            keywords: ['voice', 'speak', 'listen', 'say', 'read aloud', 'voice input'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'system',
        name: 'System Agent',
        description: 'System operations, shell commands, and app control',
        icon: '⚙️',
        capabilities: [
          AgentCapability(
            name: 'system_operations',
            description: 'System and shell operations',
            toolNames: ['shell_exec', 'system_info', 'system_open_app', 'system_open_url', 'system_shutdown', 'system_restart', 'system_sleep', 'system_lock'],
            keywords: ['shell', 'terminal', 'command', 'run', 'execute', 'system', 'app', 'open', 'close', 'shutdown', 'restart'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'social',
        name: 'Social Agent',
        description: 'Social media management across platforms',
        icon: '📱',
        capabilities: [
          AgentCapability(
            name: 'social_operations',
            description: 'Social media posting and management',
            toolNames: ['facebook_post', 'facebook_read_posts', 'facebook_page_info'],
            keywords: ['facebook', 'instagram', 'telegram', 'whatsapp', 'discord', 'social', 'post', 'tweet'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'code',
        name: 'Coding Agent',
        description: 'Execute code and manage code projects',
        icon: '💻',
        capabilities: [
          AgentCapability(
            name: 'code_operations',
            description: 'Code execution and project management',
            toolNames: ['code_execute', 'git_status', 'git_add', 'git_commit', 'git_push', 'git_pull', 'git_diff', 'git_log', 'git_branch', 'git_checkout', 'git_merge'],
            keywords: ['code', 'python', 'javascript', 'run code', 'git', 'commit', 'push', 'repository'],
          ),
        ],
      ),
      const RegisteredAgent(
        type: 'automation',
        name: 'Automation Agent',
        description: 'Schedule tasks, create automations, manage workflows',
        icon: '⚡',
        capabilities: [
          AgentCapability(
            name: 'scheduler_operations',
            description: 'Task scheduling and automation',
            toolNames: ['scheduler_create', 'scheduler_list', 'scheduler_cancel', 'create_automation_pattern', 'get_patterns_by_trigger'],
            keywords: ['schedule', 'automate', 'repeat', 'cron', 'timer', 'workflow', 'automate'],
          ),
        ],
      ),
    ]);
  }

  void register(RegisteredAgent agent) {
    _agents.removeWhere((a) => a.type == agent.type);
    _agents.add(agent);
  }

  RegisteredAgent? findByType(String type) {
    try {
      return _agents.firstWhere((a) => a.type == type);
    } catch (_) {
      return null;
    }
  }

  RegisteredAgent? findByTool(String toolName) {
    try {
      return _agents.firstWhere((a) => a.canHandle(toolName));
    } catch (_) {
      return null;
    }
  }

  List<RegisteredAgent> findMatchingAgents(String goal) {
    return _agents.where((a) => a.matchesGoal(goal)).toList();
  }

  List<String> get allKeywords {
    return _agents.expand((a) => a.allKeywords).toList();
  }

  Map<String, String> get toolToAgentMap {
    final map = <String, String>{};
    for (final agent in _agents) {
      for (final tool in agent.allToolNames) {
        map[tool] = agent.type;
      }
    }
    return map;
  }
}
