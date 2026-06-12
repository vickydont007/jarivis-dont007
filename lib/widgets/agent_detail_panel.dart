import 'package:flutter/material.dart';
import '../core/dynamic_agent.dart';
import '../core/agent_network.dart';

class AgentDetailPanel extends StatelessWidget {
  final DynamicAgent agent;
  final AgentNetwork network;
  final VoidCallback? onClose;
  final Function(String)? onKill;
  final Function(String, String)? onSendTask;

  const AgentDetailPanel({
    super.key,
    required this.agent,
    required this.network,
    this.onClose,
    this.onKill,
    this.onSendTask,
  });

  @override
  Widget build(BuildContext context) {
    final connectedAgents = network.getConnectedAgents(agent.id);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          top: BorderSide(
            color: agent.color.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: agent.color.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: agent.color.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: agent.color.withValues(alpha: 0.2),
                    border: Border.all(color: agent.color, width: 2),
                  ),
                  child: Icon(
                    _getIcon(agent.icon),
                    color: agent.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        agent.role.name.toUpperCase(),
                        style: TextStyle(
                          color: agent.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard(
                        'Tasks Done',
                        '${agent.tasksCompleted}',
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Failed',
                        '${agent.tasksFailed}',
                        Colors.red,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Uptime',
                        agent.uptimeFormatted,
                        Colors.cyan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (connectedAgents.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.link, color: Colors.grey[400], size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Connected Agents',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: connectedAgents.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: a.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: a.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                a.name,
                                style: TextStyle(
                                  color: a.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (agent.lastTaskResult != null) ...[
                    Row(
                      children: [
                        Icon(Icons.article, color: Colors.grey[400], size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Last Result',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF30363D),
                        ),
                      ),
                      child: Text(
                        agent.lastTaskResult!,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 11,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onKill?.call(agent.id),
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('Kill Agent'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;
    switch (agent.status) {
      case AgentStatus.active:
        color = Colors.green;
        text = 'ACTIVE';
        break;
      case AgentStatus.busy:
        color = Colors.orange;
        text = 'BUSY';
        break;
      case AgentStatus.idle:
        color = Colors.grey;
        text = 'IDLE';
        break;
      case AgentStatus.failed:
        color = Colors.red;
        text = 'FAILED';
        break;
      case AgentStatus.spawning:
        color = Colors.cyan;
        text = 'SPAWNING';
        break;
      case AgentStatus.terminated:
        color = Colors.red;
        text = 'DEAD';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'hub':
        return Icons.hub;
      case 'send':
        return Icons.send;
      case 'palette':
        return Icons.palette;
      case 'chat':
        return Icons.chat;
      case 'comment':
        return Icons.comment;
      case 'target':
        return Icons.gps_fixed;
      case 'search':
        return Icons.search;
      case 'eye':
        return Icons.visibility;
      case 'code':
        return Icons.code;
      case 'schedule':
        return Icons.schedule;
      case 'extension':
        return Icons.extension;
      default:
        return Icons.circle;
    }
  }
}
