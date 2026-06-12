import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dynamic_agent.dart';
import '../core/agent_network.dart';
import '../core/task_router.dart';
import '../providers/app_provider.dart';
import '../widgets/agent_network_painter.dart';
import '../widgets/agent_stats_bar.dart';
import '../widgets/agent_detail_panel.dart';

class AgentNetworkScreen extends ConsumerStatefulWidget {
  const AgentNetworkScreen({super.key});

  @override
  ConsumerState<AgentNetworkScreen> createState() => _AgentNetworkScreenState();
}

class _AgentNetworkScreenState extends ConsumerState<AgentNetworkScreen>
    with TickerProviderStateMixin {
  late AgentNetwork _network;
  late TaskRouter _router;
  late final AnimationController _animationController;
  late final AnimationController _spawnAnimationController;
  DynamicAgent? _selectedAgent;
  StreamSubscription? _eventSubscription;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _showDetailPanel = false;

  @override
  void initState() {
    super.initState();
    // Use shared AgentNetwork from AppState
    final appState = ref.read(appStateProvider);
    _network = appState.agentNetwork!;
    _router = TaskRouter(_network);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _spawnAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _eventSubscription = _network.eventStream.listen((event) {
      if (mounted) setState(() {});
    });

    _animationController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _spawnAnimationController.dispose();
    _eventSubscription?.cancel();
    _network.dispose();
    _router.dispose();
    super.dispose();
  }

  void _onNodeTap(DynamicAgent agent) {
    setState(() {
      _selectedAgent = agent;
      _showDetailPanel = true;
    });
  }

  void _onCanvasTap(TapUpDetails details) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = details.localPosition;
    final agent = _network.getNodeAtPosition(localPos);

    if (agent != null) {
      _onNodeTap(agent);
    } else {
      setState(() {
        _selectedAgent = null;
        _showDetailPanel = false;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _offset += details.delta;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_scale * details.scale).clamp(0.3, 3.0);
    });
  }

  void _spawnNewAgent() {
    String agentName = '';
    AgentRole selectedRole = AgentRole.custom;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text(
            'Spawn New Agent',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Agent Name',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                ),
                onChanged: (v) => agentName = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AgentRole>(
                value: selectedRole,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Role',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                ),
                items: AgentRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedRole = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: agentName.isNotEmpty
                  ? () {
                      Navigator.pop(context);
                      _doSpawnAgent(agentName, selectedRole);
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('Spawn'),
            ),
          ],
        ),
      ),
    );
  }

  void _doSpawnAgent(String name, AgentRole role) {
    final existingAgent = _selectedAgent;
    final connections = <String>[];
    if (existingAgent != null) {
      connections.add(existingAgent.id);
    } else {
      final orchestrator = _network.agents
          .where((a) => a.role == AgentRole.orchestrator && a.isAlive)
          .toList();
      if (orchestrator.isNotEmpty) {
        connections.add(orchestrator.first.id);
      }
    }

    _network.spawnAgent(
      name: name,
      role: role,
      connectTo: connections,
    );

    _spawnAnimationController.forward(from: 0);
  }

  void _killAgent(String agentId) {
    _network.removeAgent(agentId);
    setState(() {
      _selectedAgent = null;
      _showDetailPanel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          AgentStatsBar(network: _network),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTapUp: _onCanvasTap,
                  onPanUpdate: _onPanUpdate,
                  onScaleUpdate: _onScaleUpdate,
                  child: CustomPaint(
                    painter: AgentNetworkPainter(
                      network: _network,
                      animation: _animationController,
                      selectedAgentId: _selectedAgent?.id,
                      scale: _scale,
                      offset: _offset,
                    ),
                    size: Size.infinite,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _buildToolButton(Icons.add, 'Spawn Agent', _spawnNewAgent),
                      const SizedBox(height: 8),
                      _buildToolButton(Icons.center_focus_strong, 'Reset View', () {
                        setState(() {
                          _scale = 1.0;
                          _offset = Offset.zero;
                        });
                      }),
                      const SizedBox(height: 8),
                      _buildToolButton(Icons.grid_view, 'Layout', () {
                        final bounds = Rect.fromLTWH(0, 0, 900, 600);
                        _network.applyForceLayout(bounds);
                        setState(() {});
                      }),
                    ],
                  ),
                ),
                if (_showDetailPanel && _selectedAgent != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AgentDetailPanel(
                      agent: _selectedAgent!,
                      network: _network,
                      onClose: () {
                        setState(() {
                          _showDetailPanel = false;
                          _selectedAgent = null;
                        });
                      },
                      onKill: _killAgent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.cyan.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, color: Colors.cyan, size: 20),
        ),
      ),
    );
  }
}
