import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dynamic_agent.dart' as dyn_agent;
import '../core/agent_network.dart';
import '../core/task_router.dart';
import '../core/agent_orchestrator.dart' as orch;
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
  orch.AgentOrchestrator? _orchestrator;
  late final AnimationController _animationController;
  late final AnimationController _spawnAnimationController;
  dyn_agent.DynamicAgent? _selectedAgent;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _taskSubscription;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _showDetailPanel = false;
  List<orch.AgentTask> _runningTasks = [];

  @override
  void initState() {
    super.initState();
    // Use shared AgentNetwork from AppState
    final appState = ref.read(appStateProvider);
    _network = appState.agentNetwork!;
    _orchestrator = appState.agentOrchestrator;
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

    // Listen to orchestrator task updates
    if (_orchestrator != null) {
      _taskSubscription = _orchestrator!.taskStream.listen((task) {
        if (mounted) {
          setState(() {
            _runningTasks = _orchestrator!.getTasksByStatus(orch.AgentStatus.running);
          });
        }
      });
    }

    _animationController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _spawnAnimationController.dispose();
    _eventSubscription?.cancel();
    _taskSubscription?.cancel();
    _network.dispose();
    _router.dispose();
    super.dispose();
  }

  void _onNodeTap(dyn_agent.DynamicAgent agent) {
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

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _offset += details.focalPointDelta;
      _scale = (_scale * details.scale).clamp(0.3, 3.0);
    });
  }

  void _spawnNewAgent() {
    String agentName = '';
    dyn_agent.AgentRole selectedRole = dyn_agent.AgentRole.custom;

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
              DropdownButtonFormField<dyn_agent.AgentRole>(
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
                items: dyn_agent.AgentRole.values.map((role) {
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

  void _doSpawnAgent(String name, dyn_agent.AgentRole role) {
    final existingAgent = _selectedAgent;
    final connections = <String>[];
    if (existingAgent != null) {
      connections.add(existingAgent.id);
    } else {
      final orchestrator = _network.agents
          .where((a) => a.role == dyn_agent.AgentRole.orchestrator && a.isAlive)
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
          if (_runningTasks.isNotEmpty)
            Container(
              height: 120,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.play_circle, color: Colors.cyan, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Running Tasks',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        '${_runningTasks.length} active',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                      Expanded(
                    child: ListView.builder(
                      itemCount: _runningTasks.length,
                      itemBuilder: (context, index) {
                        final task = _runningTasks[index];
                        final agent = _network.agents.firstWhere(
                          (a) => a.id == task.agentId,
                          orElse: () => dyn_agent.DynamicAgent(id: 'unknown', name: 'Unknown', role: dyn_agent.AgentRole.custom),
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      task.description.length > 50 
                                        ? '${task.description.substring(0, 50)}...'
                                        : task.description,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                    Text(
                                      'Agent: ${agent.name} (${agent.role.name})',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTapUp: _onCanvasTap,
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
