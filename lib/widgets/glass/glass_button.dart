import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum GlassButtonVariant { primary, secondary, ghost, danger, icon }

class GlassButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final GlassButtonVariant variant;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isCompact;
  final double? width;
  final Color? accentColor;

  const GlassButton({
    super.key,
    this.label,
    this.icon,
    this.variant = GlassButtonVariant.primary,
    this.onPressed,
    this.isLoading = false,
    this.isCompact = false,
    this.width,
    this.accentColor,
  });

  const GlassButton.icon({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.accentColor,
  })  : label = null,
        variant = GlassButtonVariant.icon,
        isCompact = false,
        width = null;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    final accent = widget.accentColor ?? AppColors.accent;
    switch (widget.variant) {
      case GlassButtonVariant.primary:
        if (_isHovered) return AppColors.accentHover;
        return accent;
      case GlassButtonVariant.secondary:
        return _isHovered
            ? AppColors.glassFillHover
            : AppColors.glassFill;
      case GlassButtonVariant.ghost:
        return _isHovered
            ? const Color(0x1A3B82F6) // rgba(59,130,246,0.10)
            : Colors.transparent;
      case GlassButtonVariant.danger:
        return _isHovered
            ? const Color(0x33EF4444) // rgba(239,68,68,0.20)
            : AppColors.errorGhost;
      case GlassButtonVariant.icon:
        return _isHovered
            ? AppColors.glassFillHover
            : Colors.transparent;
    }
  }

  Color get _textColor {
    switch (widget.variant) {
      case GlassButtonVariant.primary:
        return AppColors.textPrimary;
      case GlassButtonVariant.secondary:
        return AppColors.textSecondary;
      case GlassButtonVariant.ghost:
        return widget.accentColor ?? AppColors.accent;
      case GlassButtonVariant.danger:
        return AppColors.error;
      case GlassButtonVariant.icon:
        if (_isHovered) return AppColors.textPrimary;
        return widget.accentColor ?? AppColors.textSecondary;
    }
  }

  Color get _borderColor {
    switch (widget.variant) {
      case GlassButtonVariant.secondary:
        return _isHovered
            ? AppColors.glassBorderActive
            : AppColors.glassBorderHover;
      case GlassButtonVariant.danger:
        return const Color(0x4DEFEFEF); // rgba(239,68,68,0.30)
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIconOnly = widget.variant == GlassButtonVariant.icon;
    final effectiveHeight =
        widget.isCompact ? 36.0 : (isIconOnly ? 44.0 : AppSpacing.buttonHeight);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) {
                setState(() => _isPressed = true);
                _controller.forward();
              }
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                setState(() => _isPressed = false);
                _controller.reverse();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: widget.onPressed != null
            ? () {
                setState(() => _isPressed = false);
                _controller.reverse();
              }
            : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isIconOnly ? effectiveHeight : widget.width,
            height: effectiveHeight,
            padding: isIconOnly
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: widget.onPressed != null
                  ? _backgroundColor
                  : _backgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: widget.onPressed != null
                    ? _borderColor
                    : _borderColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _textColor,
                      ),
                    )
                  : Row(
                      mainAxisSize:
                          isIconOnly ? MainAxisSize.min : MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: _textColor),
                          if (!isIconOnly) const SizedBox(width: AppSpacing.sm),
                        ],
                        if (widget.label != null && !isIconOnly)
                          Text(
                            widget.label!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _textColor,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
