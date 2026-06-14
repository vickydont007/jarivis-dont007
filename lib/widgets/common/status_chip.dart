import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum ChipStatus { idle, active, success, warning, error }

class StatusChip extends StatelessWidget {
  final String label;
  final ChipStatus status;
  final bool isSmall;
  final bool showDot;
  final bool animate;

  const StatusChip({
    super.key,
    required this.label,
    this.status = ChipStatus.idle,
    this.isSmall = false,
    this.showDot = true,
    this.animate = true,
  });

  Color get _statusColor {
    switch (status) {
      case ChipStatus.idle:
        return AppColors.agentIdle;
      case ChipStatus.active:
        return AppColors.agentActive;
      case ChipStatus.success:
        return AppColors.success;
      case ChipStatus.warning:
        return AppColors.warning;
      case ChipStatus.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? AppSpacing.sm : AppSpacing.md,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: _statusColor.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _PulsingDot(
              color: _statusColor,
              animate: animate && status == ChipStatus.active,
              size: isSmall ? 5 : 6,
            ),
            SizedBox(width: isSmall ? 4 : 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: isSmall ? 9 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: _statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  final double size;

  const _PulsingDot({
    required this.color,
    required this.animate,
    required this.size,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(

      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(
              widget.animate
                  ? 0.5 + (_controller.value * 0.5)
                  : 1.0,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
