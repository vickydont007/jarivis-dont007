import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dynamic_agent.dart' as dyn_agent;
import '../core/agent_network.dart';
import '../core/task_router.dart';
import '../core/agent_orchestrator.dart' as orch;
import '../providers/app_provider.dart';
import '../widgets/agent_network_painter.dart';
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
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    final appState = ref.read(appStateProvider);
    _network = appState.agentNetwork!;
    _orchestrator = appState.agentOrchestrator;
    _router = TaskRouter(_network);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _spawnAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _eventSubscription = _network.eventStream.listen((event) {
      if (mounted) setState(() {});
    });

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
          backgroundColor: const Color(0xFF0A0E1A),
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
                  fillColor: const Color(0xFF050810),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
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
                  fillColor: const Color(0xFF050810),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
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

  String _getUptime() {
    if (_startTime == null) return '+00:00:00';
    final diff = DateTime.now().difference(_startTime!);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '+$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: Column(
        children: [
          _buildStatsBar(),
          _buildTitle(),
          if (_runningTasks.isNotEmpty) _buildRunningTasksPanel(),
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

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatItem('AGENTS', '${_network.agentCount}'),
          const SizedBox(width: 30),
          _buildStatItem('LINES', '${_network.connectionCount}'),
          const SizedBox(width: 30),
          _buildStatItem('TASKS', '${_network.totalTasks}'),
          const SizedBox(width: 30),
          _buildStatItem('UPTIME', _getUptime()),
          const SizedBox(width: 30),
          _buildActiveBadge(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_network.activeAgents} ACTIVE',
            style: const TextStyle(
              color: Color(0xFF00BCD4),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Text(
        'Solar System',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildRunningTasksPanel() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFA500).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle, color: Color(0xFFFFA500), size: 16),
              const SizedBox(width: 6),
              const Text(
                'Running Tasks',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${_runningTasks.length} active',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: _runningTasks.length,
              itemBuilder: (context, index) {
                final task = _runningTasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050810),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFA500)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.description.length > 40
                              ? '${task.description.substring(0, 40)}...'
                              : task.description,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildToolButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF1E3A5F).withOpacity(0.5),
            ),
          ),
          child: Icon(icon, color: const Color(0xFF4A90D9), size: 18),
        ),
      ),
    );
  }
}
