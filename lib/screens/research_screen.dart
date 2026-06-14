import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/services/memory_search.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/glass/glass_tab_bar.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  int _selectedTab = 0;
  final List<_WatchlistItem> _watchlists = [];
  final TextEditingController _topicController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlists();
  }

  Future<void> _loadWatchlists() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('research_watchlists');
      if (data != null) {
        final list = jsonDecode(data) as List;
        _watchlists.clear();
        for (final item in list) {
          _watchlists.add(_WatchlistItem(
            topic: item['topic'],
            addedAt: DateTime.parse(item['addedAt']),
            lastChecked: item['lastChecked'] != null
                ? DateTime.parse(item['lastChecked'])
                : null,
            findingCount: item['findingCount'] ?? 0,
          ));
        }
      }
    } catch (e) {
      // Use empty list
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveWatchlists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _watchlists.map((w) => {
      'topic': w.topic,
      'addedAt': w.addedAt.toIso8601String(),
      'lastChecked': w.lastChecked?.toIso8601String(),
      'findingCount': w.findingCount,
    }).toList();
    await prefs.setString('research_watchlists', jsonEncode(data));
  }

  Future<void> _addWatchlist() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _isLoading = true);

    // Search for the topic using memory search
    final search = ref.read(memorySearchProvider);
    final results = await search.search(topic, limit: 5);

    setState(() {
      _watchlists.insert(0, _WatchlistItem(
        topic: topic,
        addedAt: DateTime.now(),
        lastChecked: DateTime.now(),
        findingCount: results.length,
      ));
      _isLoading = false;
    });

    _topicController.clear();
    await _saveWatchlists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxxl, 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔬 Research',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Track topics and discover insights',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Add topic input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Row(
                children: [
                  Expanded(
                    child: GlassTextField(
                      controller: _topicController,
                      hintText: 'Add a topic to watch...',
                      onSubmitted: (_) => _addWatchlist(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GlassButton(
                    onPressed: _addWatchlist,
                    label: 'Watch',
                    icon: Icons.add,
                    isCompact: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            GlassTabBar(
              tabs: const [
                GlassTab(label: '📋 Watchlists'),
                GlassTab(label: '📖 Knowledge Base'),
              ],
              selectedIndex: _selectedTab,
              onTabChanged: (i) => setState(() => _selectedTab = i),
            ),

            const SizedBox(height: AppSpacing.xl),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _selectedTab == 0
                      ? _buildWatchlists()
                      : _buildKnowledgeBase(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlists() {
    if (_watchlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Start tracking topics',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add topics above and JARVIS will monitor\nyour memory for relevant findings',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      itemCount: _watchlists.length,
      itemBuilder: (context, index) {
        final item = _watchlists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentGhost,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Center(
                  child: Text('📌', style: TextStyle(fontSize: 20)),
                ),
              ),
              title: Text(
                item.topic,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '${item.findingCount} findings • Added ${_formatDate(item.addedAt)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                onPressed: () {
                  setState(() => _watchlists.removeAt(index));
                  _saveWatchlists();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKnowledgeBase() {
    return FutureBuilder<List<MemorySearchResult>>(
      future: ref.read(memorySearchProvider).getRecentMemories(limit: 30),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final memories = snapshot.data!;
        if (memories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📚', style: TextStyle(fontSize: 48)),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Your knowledge base is empty',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Memories from conversations will appear here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          itemCount: memories.length,
          itemBuilder: (context, index) {
            final mem = memories[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: GlassCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentGhost,
                    child: Text(
                      _getCategoryEmoji(mem.category),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  title: Text(
                    mem.content.length > 80
                        ? '${mem.content.substring(0, 80)}...'
                        : mem.content,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${mem.category} • ${_formatDate(mem.createdAt)}',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'chat': return '💬';
      case 'fact': return '📌';
      case 'preference': return '❤️';
      case 'task': return '✅';
      case 'event': return '📅';
      default: return '📝';
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}

class _WatchlistItem {
  final String topic;
  final DateTime addedAt;
  final DateTime? lastChecked;
  final int findingCount;

  _WatchlistItem({
    required this.topic,
    required this.addedAt,
    this.lastChecked,
    this.findingCount = 0,
  });
}
