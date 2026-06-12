import 'tool.dart';
import '../core/agent_network.dart';
import '../core/dynamic_agent.dart';

class AgentSpawnTool extends Tool {
  final AgentNetwork _network;

  AgentSpawnTool(this._network)
      : super(
          name: 'agent_spawn',
          description: 'Spawn a new agent in the network',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Agent name',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'role',
              description: 'Agent role',
              type: ToolParameterType.string,
              required: true,
              enumValues: [
                'orchestrator', 'outreach', 'content', 'dm', 'comment',
                'lead', 'research', 'monitor', 'code', 'scheduler', 'custom',
              ],
            ),
            const ToolParameter(
              name: 'connect_to',
              description: 'List of agent IDs to connect to',
              type: ToolParameterType.array,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String;
    final roleStr = params['role'] as String;
    final connectTo = (params['connect_to'] as List?)?.cast<String>() ?? [];

    final role = AgentRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => AgentRole.custom,
    );

    try {
      final agent = _network.spawnAgent(
        name: name,
        role: role,
        connectTo: connectTo,
      );
      return ToolResult.success('Agent spawned: ${agent.id}', metadata: {
        'id': agent.id,
        'name': name,
        'role': roleStr,
      });
    } catch (e) {
      return ToolResult.error('Failed to spawn agent: $e');
    }
  }
}

class AgentKillTool extends Tool {
  final AgentNetwork _network;

  AgentKillTool(this._network)
      : super(
          name: 'agent_kill',
          description: 'Kill/remove an agent from the network',
          parameters: [
            const ToolParameter(
              name: 'agent_id',
              description: 'ID of the agent to kill',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final agentId = params['agent_id'] as String;
    try {
      _network.removeAgent(agentId);
      return ToolResult.success('Agent killed: $agentId');
    } catch (e) {
      return ToolResult.error('Failed to kill agent: $e');
    }
  }
}

class AgentStatusTool extends Tool {
  final AgentNetwork _network;

  AgentStatusTool(this._network)
      : super(
          name: 'agent_status',
          description: 'Get status of a specific agent or all agents',
          parameters: [
            const ToolParameter(
              name: 'agent_id',
              description: 'Agent ID (optional, returns all if not specified)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final agentId = params['agent_id'] as String?;

    try {
      if (agentId != null && agentId.isNotEmpty) {
        final agent = _network.getAgentById(agentId);
        if (agent == null) {
          return ToolResult.error('Agent not found: $agentId');
        }
        return ToolResult.success(_agentToMap(agent));
      }

      final agents = _network.agents.where((a) => a.isAlive).map(_agentToMap).toList();
      return ToolResult.success(agents, metadata: {
        'total': _network.agentCount,
        'active': _network.activeAgents,
        'connections': _network.connectionCount,
        'tasks_completed': _network.totalTasks,
      });
    } catch (e) {
      return ToolResult.error('Failed to get agent status: $e');
    }
  }

  Map<String, dynamic> _agentToMap(DynamicAgent agent) {
    return {
      'id': agent.id,
      'name': agent.name,
      'role': agent.role.name,
      'status': agent.status.name,
      'tasks_completed': agent.tasksCompleted,
      'tasks_failed': agent.tasksFailed,
      'uptime': agent.uptimeFormatted,
    };
  }
}

List<Tool> getAllAgentTools(AgentNetwork network) {
  return [
    AgentSpawnTool(network),
    AgentKillTool(network),
    AgentStatusTool(network),
  ];
}
