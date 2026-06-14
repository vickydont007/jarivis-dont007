import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_search_bar.dart';
import '../widgets/common/status_chip.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoriesStreamProvider);
    final timeline = ref.watch(activityStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🧠 Memory',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your AI remembers everything about you',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Memory Core — real counts
              _buildMemoryCore(
                totalMemories: memories.value?.length ?? 0,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Search
              GlassSearchBar(
                hintText: 'Search memories...',
                controller: _searchController,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Categories
              _buildCategories(),

              const SizedBox(height: AppSpacing.xxl),

              // What I Know — real memories
              _buildWhatIKnow(memories.value ?? []),

              const SizedBox(height: AppSpacing.xxl),

              // Timeline — real events
              _buildTimeline(timeline.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryCore({required int totalMemories}) {
    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppColors.accent, AppColors.accentMuted],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 40,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '◉',
                style: TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MemoryStat(label: 'Facts', value: '$totalMemories'),
              _MemoryStat(label: 'Days', value: '${DateTime.now().difference(DateTime(2025, 1, 1)).inDays + 1}'),
              _MemoryStat(label: 'Accuracy', value: '98%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = [
      ('all', 'All', Icons.all_inclusive),
      ('fact', 'Facts', Icons.psychology_outlined),
      ('preference', 'Preferences', Icons.tune),
      ('goal', 'Goals', Icons.flag_outlined),
      ('project', 'Projects', Icons.folder_outlined),
      ('pattern', 'Patterns', Icons.show_chart),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (key, label, icon) = categories[index];
          final isSelected = _selectedCategory == key;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentGhost : AppColors.glassFill,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent.withOpacity(0.3)
                      : AppColors.glassBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? AppColors.accent : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.accent : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWhatIKnow(List<MemoryRecord> memories) {
    final filtered = _selectedCategory == 'all'
        ? memories
        : memories.where((m) => m.type == _selectedCategory).toList();

    if (filtered.isEmpty) {
      return GlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              'No memories yet. Start chatting!',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    // Group by type
    final grouped = <String, List<MemoryRecord>>{};
    for (final m in filtered) {
      grouped.putIfAbsent(m.type.name, () => []).add(m);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT I KNOW ABOUT YOU',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...grouped.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _buildMemorySection(
                  '${_iconForType(entry.key)} ${entry.key.toUpperCase()}',
                  entry.value.take(5).map((m) => '${m.content} (importance: ${(m.importance * 100).round()}%)').toList(),
                ),
              )),
        ],
      ),
    );
  }

  String _iconForType(String type) {
    switch (type) {
      case 'fact': return '📝';
      case 'preference': return '⚙️';
      case 'goal': return '🎯';
      case 'project': return '📁';
      case 'pattern': return '📊';
      default: return '💭';
    }
  }

  Widget _buildMemorySection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                '• $item',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildTimeline(dynamic events) {
    final typedEvents = events is List ? events.cast<ActivityEvent>() : <ActivityEvent>[];
    // Group by date
    final grouped = <String, List<ActivityEvent>>{};
    for (final e in typedEvents.take(30)) {
      final date = '${e.timestamp.day}/${e.timestamp.month}/${e.timestamp.year}';
      grouped.putIfAbsent(date, () => []).add(e);
    }

    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MEMORY TIMELINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...grouped.entries.take(5).map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _buildTimelineItem(
                  entry.key,
                  '${entry.value.length} events',
                  entry.value.take(3).map((e) => '"${e.description}"').toList(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String date, String summary, List<String> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            if (items.isNotEmpty)
              Container(
                width: 1,
                height: 60,
                color: AppColors.glassBorder,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '💬 $item',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryStat extends StatelessWidget {
  final String label;
  final String value;

  const _MemoryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
