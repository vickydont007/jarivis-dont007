import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../core/models/orb_state.dart';
import 'orb_painter.dart';

class AnimatedOrb extends StatefulWidget {
  final OrbState state;
  final double size;
  final VoidCallback? onTap;
  final String? label;

  const AnimatedOrb({
    super.key,
    this.state = OrbState.idle,
    this.size = AppSpacing.orbIdle,
    this.onTap,
    this.label,
  });

  @override
  State<AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<AnimatedOrb>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _rotateController;
  late AnimationController _stateController;

  @override
  void initState() {
    super.initState();

    // Breathing animation (continuous)
    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    // Rotation animation (continuous for thinking state)
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // State transition animation
    _stateController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _updateControllerForState();
  }

  @override
  void didUpdateWidget(AnimatedOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateControllerForState();
    }
  }

  void _updateControllerForState() {
    switch (widget.state) {
      case OrbState.idle:
        _breatheController.duration = const Duration(milliseconds: 3000);
        _rotateController.stop();
        break;
      case OrbState.listening:
        _breatheController.duration = const Duration(milliseconds: 800);
        _rotateController.stop();
        break;
      case OrbState.thinking:
        _breatheController.duration = const Duration(milliseconds: 1500);
        _rotateController.repeat();
        break;
      case OrbState.speaking:
        _breatheController.duration = const Duration(milliseconds: 500);
        _rotateController.stop();
        break;
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _rotateController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _breatheController,
              _rotateController,
            ]),
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: OrbPainter(
                  state: widget.state,
                  animationValue: _breatheController.value,
                  rotationValue: _rotateController.value,
                ),
              );
            },
          ),
          if (widget.label != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
