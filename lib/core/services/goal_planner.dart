import 'dart:async';
import 'dart:convert';
import '../models/workflow.dart';
import '../agents/agent_registry.dart';
import '../ai_engine.dart';

class GoalPlan {
  final String goal;
  final List<WorkflowTask> tasks;
  final String summary;
  final DateTime createdAt;

  GoalPlan({
    required this.goal,
    required this.tasks,
    required this.summary,
    required this.createdAt,
  });
}

class GoalPlanner {
  final AIEngine? Function() _getEngine;
  final AgentRegistry _registry;

  final String? _profileContext;

  GoalPlanner({
    required AIEngine? Function() getEngine,
    required AgentRegistry registry,
    String? profileContext,
  })  : _getEngine = getEngine,
        _registry = registry,
        _profileContext = profileContext;

  Future<GoalPlan> planGoal(String goal) async {
    final engine = _getEngine();
    if (engine != null) {
      try {
        return await _planWithAI(goal, engine);
      } catch (e) {
        return _planWithRules(goal);
      }
    }
    return _planWithRules(goal);
  }

  Future<GoalPlan> _planWithAI(String goal, AIEngine engine) async {
    final toolMap = _registry.toolToAgentMap;
    final toolsList = toolMap.entries.map((e) => '${e.key} (${e.value})').join('\n');
    final profileBlock = _profileContext != null && _profileContext.isNotEmpty
        ? '\nUSER PROFILE CONTEXT:\n$_profileContext\n- Personalize the plan to the user\'s known projects, goals, and skills\n'
        : '';

    final prompt = '''You are a goal planner for an AI assistant. Decompose the user's goal into a sequence of tool calls.$profileBlock

AVAILABLE AGENTS AND TOOLS:
$toolsList

USER GOAL: "$goal"

Respond with ONLY a JSON array of tasks. Each task must have:
- "agentType": the agent type (memory, research, file, email, calendar, voice, system, social, code, automation)
- "toolName": the exact tool name to call
- "description": what this step does
- "parameters": object with tool parameters (use placeholder values that will be filled at runtime)
- "dependsOn": array of task indices (0-based) this task depends on (empty for independent tasks)
- "outputKey": key to store result in workflow context (e.g. "report", "email_id")

Example:
[
  {"agentType":"research","toolName":"research_topic","description":"Research competitors","parameters":{"topic":"OpenAI competitors"},"dependsOn":[],"outputKey":"research_report"},
  {"agentType":"file","toolName":"file_write","description":"Save report","parameters":{"path":"/Users/abc/Research/report.md","content":"{{report}}"},"dependsOn":[0],"outputKey":"report_file"},
  {"agentType":"email","toolName":"email_draft","description":"Draft email with report","parameters":{"subject":"Research Report","body":"{{report}}"},"dependsOn":[1],"outputKey":"draft"}
]

Rules:
- Use {{key}} syntax to reference outputs from previous tasks
- Minimize the number of tasks — combine related operations
- Always include a memory save step at the end
- If the goal doesn't need a tool, describe what you'd do and skip it
- Only include tools that exist in the AVAILABLE TOOLS list
- Keep it simple: 2-6 tasks maximum

Respond with ONLY the JSON array, no explanation.''';

    final response = await engine.sendMessage(prompt);
    final text = response.trim();

    final jsonStart = text.indexOf('[');
    final jsonEnd = text.lastIndexOf(']');
    if (jsonStart == -1 || jsonEnd == -1) {
      throw Exception('Invalid AI response format');
    }

    final jsonStr = text.substring(jsonStart, jsonEnd + 1);
    final List<dynamic> taskMaps = jsonDecode(jsonStr);

    final tasks = <WorkflowTask>[];
    for (var i = 0; i < taskMaps.length; i++) {
      final tm = taskMaps[i];
      tasks.add(WorkflowTask(
        id: 'task_$i',
        agentType: tm['agentType'] ?? 'system',
        toolName: tm['toolName'] ?? '',
        description: tm['description'] ?? '',
        parameters: Map<String, dynamic>.from(tm['parameters'] ?? {}),
        dependsOn: (tm['dependsOn'] as List? ?? []).map((d) => 'task_$d').toList(),
        priority: i,
        outputKeys: tm['outputKey'] != null ? [tm['outputKey']] : [],
      ));
    }

    return GoalPlan(
      goal: goal,
      tasks: tasks,
      summary: 'AI-planned workflow with ${tasks.length} steps',
      createdAt: DateTime.now(),
    );
  }

  GoalPlan _planWithRules(String goal) {
    final lower = goal.toLowerCase();
    final tasks = <WorkflowTask>[];
    var idx = 0;

    if (lower.contains('research') || lower.contains('search') || lower.contains('find') || lower.contains('look up')) {
      final topic = _extractTopic(lower);
      tasks.add(WorkflowTask(
        id: 'task_${idx++}',
        agentType: 'research',
        toolName: 'research_topic',
        description: 'Research: $topic',
        parameters: {'topic': topic},
        outputKeys: ['research_report'],
      ));
    }

    if (lower.contains('competitor') || lower.contains('market') || lower.contains('company')) {
      final topic = _extractTopic(lower);
      if (lower.contains('competitor')) {
        tasks.add(WorkflowTask(
          id: 'task_${idx++}',
          agentType: 'research',
          toolName: 'research_competitors',
          description: 'Research competitors in $topic',
          parameters: {'industry': topic},
          outputKeys: ['competitor_report'],
        ));
      } else if (lower.contains('company')) {
        tasks.add(WorkflowTask(
          id: 'task_${idx++}',
          agentType: 'research',
          toolName: 'research_company',
          description: 'Research company: $topic',
          parameters: {'company': topic},
          outputKeys: ['company_report'],
        ));
      } else {
        tasks.add(WorkflowTask(
          id: 'task_${idx++}',
          agentType: 'research',
          toolName: 'research_market',
          description: 'Research market: $topic',
          parameters: {'market': topic},
          outputKeys: ['market_report'],
        ));
      }
    }

    if (lower.contains('email') || lower.contains('send') || lower.contains('mail')) {
      tasks.add(WorkflowTask(
        id: 'task_${idx++}',
        agentType: 'email',
        toolName: 'email_draft',
        description: 'Draft email',
        parameters: {'subject': 'Research Report', 'body': '{{report}}'},
        dependsOn: tasks.isNotEmpty ? [tasks.last.id] : [],
        outputKeys: ['email_draft'],
      ));
      if (lower.contains('send')) {
        tasks.add(WorkflowTask(
          id: 'task_${idx++}',
          agentType: 'email',
          toolName: 'email_send',
          description: 'Send email',
          parameters: {'to': '{{email_to}}', 'subject': '{{email_subject}}', 'body': '{{email_body}}'},
          dependsOn: [tasks.last.id],
          outputKeys: ['email_sent'],
        ));
      }
    }

    if (lower.contains('save') || lower.contains('file') || lower.contains('write') || lower.contains('report')) {
      final reportRef = tasks.isNotEmpty ? '{{${tasks.last.outputKeys.first}}}' : '';
      tasks.add(WorkflowTask(
        id: 'task_${idx++}',
        agentType: 'file',
        toolName: 'file_write',
        description: 'Save report to file',
        parameters: {
          'path': '/Users/abc/Research/${_extractTopic(lower).replaceAll(' ', '_')}_report.md',
          'content': reportRef,
        },
        dependsOn: tasks.isNotEmpty ? [tasks.last.id] : [],
        outputKeys: ['report_file'],
      ));
    }

    if (lower.contains('calendar') || lower.contains('event') || lower.contains('meeting') || lower.contains('schedule')) {
      tasks.add(WorkflowTask(
        id: 'task_${idx++}',
        agentType: 'calendar',
        toolName: 'calendar_create_event',
        description: 'Create calendar event',
        parameters: {'title': '{{event_title}}', 'date': '{{event_date}}', 'time': '{{event_time}}'},
        outputKeys: ['calendar_event'],
      ));
    }

    if (tasks.isEmpty) {
      final topic = _extractTopic(lower);
      tasks.add(WorkflowTask(
        id: 'task_0',
        agentType: 'research',
        toolName: 'research_topic',
        description: 'Research: $topic',
        parameters: {'topic': topic},
        outputKeys: ['research_report'],
      ));
    }

    tasks.add(WorkflowTask(
      id: 'task_${idx++}',
      agentType: 'memory',
      toolName: 'memory_add',
      description: 'Save workflow result to memory',
      parameters: {'content': 'Completed workflow: $goal', 'category': 'workflow'},
      dependsOn: tasks.isNotEmpty ? [tasks.last.id] : [],
    ));

    return GoalPlan(
      goal: goal,
      tasks: tasks,
      summary: 'Rule-based workflow with ${tasks.length} steps',
      createdAt: DateTime.now(),
    );
  }

  String _extractTopic(String goal) {
    final prefixes = [
      'research', 'search', 'find', 'look up', 'analyze', 'investigate',
      'about', 'on', 'for', 'email me', 'send me', 'save',
    ];
    var topic = goal;
    for (final prefix in prefixes) {
      if (topic.contains(prefix)) {
        topic = topic.split(prefix).last.trim();
      }
    }
    final stopWords = ['and email', 'and save', 'and send', 'and write', 'report', 'competitors', 'market', 'company'];
    for (final stop in stopWords) {
      if (topic.contains(stop)) {
        topic = topic.split(stop).first.trim();
      }
    }
    return topic.isEmpty ? goal : topic;
  }
}
