import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';

enum GlassCardVariant { default_, accent, status, inline, modal }

class GlassCard extends StatefulWidget {
  final Widget child;
  final GlassCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool interactive;
  final Color? statusColor;

  const GlassCard({
    super.key,
    required this.child,
    this.variant = GlassCardVariant.default_,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.interactive = false,
    this.statusColor,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.variant) {
      case GlassCardVariant.accent:
        return const Color(0x0F3B82F6); // rgba(59,130,246,0.06)
      case GlassCardVariant.status:
        return widget.statusColor != null
            ? widget.statusColor!.withOpacity(0.06)
            : AppColors.glassFill;
      case GlassCardVariant.modal:
        return AppColors.modalBackground;
      case GlassCardVariant.inline:
        return const Color(0x08FFFFFF); // rgba(255,255,255,0.03)
      case GlassCardVariant.default_:
        return _isHovered ? AppColors.glassFillHover : AppColors.glassFill;
    }
  }

  Color get _borderColor {
    switch (widget.variant) {
      case GlassCardVariant.accent:
        return const Color(0x263B82F6); // rgba(59,130,246,0.15)
      case GlassCardVariant.status:
        return widget.statusColor != null
            ? widget.statusColor!.withOpacity(0.15)
            : AppColors.glassBorder;
      case GlassCardVariant.modal:
        return AppColors.glassBorderHover;
      case GlassCardVariant.inline:
        return const Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
      case GlassCardVariant.default_:
        return _isHovered
            ? AppColors.glassBorderHover
            : AppColors.glassBorder;
    }
  }

  double get _borderRadius {
    switch (widget.variant) {
      case GlassCardVariant.modal:
        return AppSpacing.radiusXl;
      case GlassCardVariant.inline:
        return AppSpacing.radiusMd;
      default:
        return AppSpacing.radiusLg;
    }
  }

  double get _blurSigma {
    switch (widget.variant) {
      case GlassCardVariant.modal:
        return 40;
      default:
        return 20;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      transform: Matrix4.identity()..scale(_isHovered ? 1.0 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: _isHovered ? AppShadows.glassHover : AppShadows.glass,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
          ),
          child: Padding(
            padding: widget.padding ??
                const EdgeInsets.all(AppSpacing.lg),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.interactive || widget.onTap != null) {
      return MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _controller.reverse();
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () => _controller.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}
