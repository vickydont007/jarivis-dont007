import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';

class CommandPalette extends StatefulWidget {
  final bool isOpen;
  final VoidCallback? onClose;
  final ValueChanged<String>? onCommand;

  const CommandPalette({
    super.key,
    this.isOpen = false,
    this.onClose,
    this.onCommand,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final FocusNode _searchController = FocusNode();
  String _query = '';

  final List<CommandItem> _commands = const [
    CommandItem(
      icon: Icons.chat_bubble_outline,
      label: 'Start a conversation',
      category: 'Quick Actions',
    ),
    CommandItem(
      icon: Icons.mic,
      label: 'Voice input',
      category: 'Quick Actions',
    ),
    CommandItem(
      icon: Icons.photo_camera_outlined,
      label: 'Analyze an image',
      category: 'Quick Actions',
    ),
    CommandItem(
      icon: Icons.alarm_add_outlined,
      label: 'Create a reminder',
      category: 'Quick Actions',
    ),
    CommandItem(
      icon: Icons.search,
      label: 'Search my memories',
      category: 'Quick Actions',
    ),
    CommandItem(
      icon: Icons.chat_bubble_outline,
      label: 'Assistant',
      shortcut: '⌘1',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.wb_sunny_outlined,
      label: 'Briefing',
      shortcut: '⌘2',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.inbox_outlined,
      label: 'Inbox',
      shortcut: '⌘3',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.science_outlined,
      label: 'Research',
      shortcut: '⌘4',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.folder_outlined,
      label: 'Projects',
      shortcut: '⌘5',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.calendar_today_outlined,
      label: 'Calendar',
      shortcut: '⌘6',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.email_outlined,
      label: 'Email',
      shortcut: '⌘7',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.folder_open_outlined,
      label: 'Files',
      shortcut: '⌘8',
      category: 'Navigate',
    ),
    CommandItem(
      icon: Icons.settings_outlined,
      label: 'Settings',
      shortcut: '⌘9',
      category: 'Navigate',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _controller.forward();
      _searchController.requestFocus();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _controller.reverse();
      _searchController.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<CommandItem> get _filteredCommands {
    if (_query.isEmpty) return _commands;
    return _commands
        .where((c) => c.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: AppColors.overlay.withOpacity(_fadeAnimation.value),
              ),
            ),
            // Modal
            Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        widget.onClose?.call();
                      }
                    },
                    child: _buildModal(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModal() {
    final filtered = _filteredCommands;
    final grouped = <String, List<CommandItem>>{};
    for (final cmd in filtered) {
      grouped.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    return Container(
      width: 560,
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: AppColors.modalBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppShadows.modal,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Column(
            children: [
              // Search input
              _buildSearchInput(),
              // Divider
              const Divider(height: 1, color: AppColors.glassBorder),
              // Results
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: grouped.length,
                  itemBuilder: (context, sectionIndex) {
                    final category = grouped.keys.elementAt(sectionIndex);
                    final items = grouped[category]!;
                    return _buildSection(category, items);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.textDisabled),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: TextEditingController(),
              focusNode: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Ask Nexa anything...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Text(
            'ESC',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<CommandItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        ...items.map((item) => _buildCommandItem(item)),
      ],
    );
  }

  Widget _buildCommandItem(CommandItem item) {
    return InkWell(
      onTap: () {
        widget.onCommand?.call(item.label);
        widget.onClose?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (item.shortcut != null)
              Text(
                item.shortcut!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDisabled,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommandItem {
  final IconData icon;
  final String label;
  final String? shortcut;
  final String category;

  const CommandItem({
    required this.icon,
    required this.label,
    this.shortcut,
    required this.category,
  });
}
