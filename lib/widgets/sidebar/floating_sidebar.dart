import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class FloatingSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final bool isVisible;
  final bool isExpanded;

  const FloatingSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.isVisible = true,
    this.isExpanded = false,
  });

  @override
  ConsumerState<FloatingSidebar> createState() => _FloatingSidebarState();
}

class _FloatingSidebarState extends ConsumerState<FloatingSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _widthAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: AppSpacing.sidebarWidth,
      end: AppSpacing.sidebarExpandedWidth,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    ));

    if (widget.isExpanded) {
      _expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FloatingSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _expandController.forward();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            if (!widget.isExpanded) {
              _expandController.reverse();
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                width: _widthAnimation.value,
                decoration: BoxDecoration(
                  color: AppColors.glassFill.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                  border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    _buildLogo(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNavItem(0, Icons.chat_bubble_outline, 'Assistant'),
                    _buildNavItem(1, Icons.wb_sunny_outlined, 'Briefing'),
                    _buildNavItem(2, Icons.inbox_outlined, 'Inbox'),
                    _buildNavItem(3, Icons.science_outlined, 'Research'),
                    _buildNavItem(4, Icons.folder_outlined, 'Projects'),
                    _buildNavItem(5, Icons.calendar_today_outlined, 'Calendar'),
                    _buildNavItem(6, Icons.email_outlined, 'Email'),
                    _buildNavItem(7, Icons.folder_open_outlined, 'Files'),
                    _buildNavItem(8, Icons.person_outline, 'Profile'),
                    _buildNavItem(9, Icons.settings_outlined, 'Settings'),
                    _buildNavItem(10, Icons.hub_outlined, 'Agents'),
                     const SizedBox(height: AppSpacing.lg),
                     const Padding(
                       padding: EdgeInsets.symmetric(horizontal: 16),
                       child: Divider(height: 1, color: AppColors.glassBorder),
                     ),
                     const SizedBox(height: AppSpacing.lg),
                     _buildNavItem(11, Icons.code_outlined, 'Dev Mode',
                         isMuted: true),
                     _buildNavItem(12, Icons.verified_outlined, 'Validate',
                         isMuted: true),
                    const SizedBox(height: AppSpacing.lg),
                    _buildUserAvatar(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '◉',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (_isHovered) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'JARVIS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {bool isMuted = false}) {
    final isSelected = index == widget.selectedIndex;
    final color = isSelected
        ? AppColors.accent
        : isMuted
            ? AppColors.textDisabled
            : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GestureDetector(
        onTap: () => widget.onIndexChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGhost
                : _isHovered
                    ? AppColors.glassFill
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              if (_isHovered) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final initial = (user?.displayName ?? 'U').substring(0, 1).toUpperCase();
    final name = user?.displayName ?? 'User';
    final email = user?.email ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (_isHovered) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
