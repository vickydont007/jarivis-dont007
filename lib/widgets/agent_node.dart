import 'package:flutter/material.dart';
import '../core/dynamic_agent.dart';

class AgentNode extends StatefulWidget {
  final DynamicAgent agent;
  final bool isSelected;
  final VoidCallback? onTap;

  const AgentNode({
    super.key,
    required this.agent,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<AgentNode> createState() => _AgentNodeState();
}

class _AgentNodeState extends State<AgentNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _spawnController;
  late Animation<double> _spawnAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: widget.agent.isActive ? 800 : 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _spawnController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _spawnAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _spawnController, curve: Curves.elasticOut),
    );

    _spawnController.forward();

    if (widget.agent.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AgentNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agent.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.agent.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spawnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _spawnAnimation,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.agent.color.withValues(alpha: 0.2),
              border: Border.all(
                color: widget.agent.color.withValues(
                  alpha: widget.isSelected ? 1.0 : 0.6,
                ),
                width: widget.isSelected ? 3.0 : 2.0,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.agent.color.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              _getIcon(widget.agent.icon),
              color: widget.agent.color,
              size: 24,
            ),
          ),
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
