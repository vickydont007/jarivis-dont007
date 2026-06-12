import 'dart:async';
import 'package:flutter/material.dart';
import '../core/agent_network.dart';

class AgentStatsBar extends StatefulWidget {
  final AgentNetwork network;

  const AgentStatsBar({super.key, required this.network});

  @override
  State<AgentStatsBar> createState() => _AgentStatsBarState();
}

class _AgentStatsBarState extends State<AgentStatsBar> {
  DateTime _startTime = DateTime.now();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _sub = widget.network.eventStream.listen((_) {
      if (mounted) setState(() {});
    });
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _uptime {
    final diff = DateTime.now().difference(_startTime);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return '+${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E14),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyan.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStat('AGENTS', '${widget.network.agentCount}', Colors.cyan),
          _buildDivider(),
          _buildStat('LINES', '${widget.network.connectionCount}', Colors.blue),
          _buildDivider(),
          _buildStat('TASKS', '${widget.network.totalTasks}', Colors.green),
          _buildDivider(),
          _buildStat('UPTIME', _uptime, Colors.orange),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.network.activeAgents > 0
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.network.activeAgents > 0
                    ? Colors.green.withValues(alpha: 0.4)
                    : Colors.orange.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.network.activeAgents > 0 ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.network.activeAgents} ACTIVE',
                  style: TextStyle(
                    color: widget.network.activeAgents > 0 ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}
