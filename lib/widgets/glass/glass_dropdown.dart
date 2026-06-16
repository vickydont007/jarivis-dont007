import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class GlassDropdown<T> extends StatefulWidget {
  final T? value;
  final List<GlassDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final IconData? prefixIcon;
  final bool isEnabled;

  const GlassDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.prefixIcon,
    this.isEnabled = true,
  });

  @override
  State<GlassDropdown<T>> createState() => _GlassDropdownState<T>();
}

class _GlassDropdownState<T> extends State<GlassDropdown<T>> {
  bool _isFocused = false;
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _toggleDropdown() {
    if (!widget.isEnabled) return;
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
    setState(() => _isOpen = !_isOpen);
  }

  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.glassBorderHover),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x4D000000),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = item.value == widget.value;
                    return InkWell(
                      onTap: () {
                        widget.onChanged?.call(item.value);
                        _removeOverlay();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        color: isSelected
                            ? AppColors.accentGhost
                            : Colors.transparent,
                        child: Row(
                          children: [
                            if (item.icon != null) ...[
                              Icon(
                                item.icon,
                                size: 16,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: AppColors.accent,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty items list gracefully
    GlassDropdownItem<T>? selectedItem;
    if (widget.items.isNotEmpty) {
      selectedItem = widget.items.firstWhere(
        (item) => item.value == widget.value,
        orElse: () => widget.items.first,
      );
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: widget.isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: AppSpacing.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: _isFocused
                  ? const Color(0x0AFFFFFF)
                  : const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isFocused
                    ? const Color(0x803B82F6)
                    : AppColors.glassBorder,
                width: _isFocused ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  Icon(
                    widget.prefixIcon,
                    size: 18,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    selectedItem?.label ?? widget.hintText ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const GlassDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });
}
