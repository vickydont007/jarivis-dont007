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
import '../widgets/common/error_state.dart';
import '../widgets/common/empty_state.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  int _selectedTab = 0;
  final List<_WatchlistItem> _watchlists = [];
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _researchTopicController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  ResearchReport? _lastReport;
  bool _isResearching = false;
  String? _researchError;

  @override
  void initState() {
    super.initState();
    _loadWatchlists();
  }

  Future<void> _loadWatchlists() async {
    setState(() { _isLoading = true; _error = null; });
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
      _error = 'Failed to load watchlists: $e';
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

  Future<void> _researchTopic(String topic) async {
    if (topic.trim().isEmpty) return;

    setState(() {
      _isResearching = true;
      _researchError = null;
      _lastReport = null;
    });

    try {
      final research = ref.read(researchServiceProvider);
      final report = await research.researchTopic(topic.trim());
      setState(() {
        _lastReport = report;
        _isResearching = false;
      });
    } catch (e) {
      setState(() {
        _researchError = 'Research failed: $e';
        _isResearching = false;
      });
    }
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
                    'Track topics, discover insights, generate reports',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            GlassTabBar(
              tabs: const [
                GlassTab(label: '📋 Watchlists'),
                GlassTab(label: '🔍 Live Research'),
                GlassTab(label: '📖 Knowledge Base'),
              ],
              selectedIndex: _selectedTab,
              onTabChanged: (i) => setState(() => _selectedTab = i),
            ),

            const SizedBox(height: AppSpacing.xl),

            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Loading research...')
                  : _error != null
                      ? ErrorState(
                          message: _error!,
                          onRetry: _loadWatchlists,
                          retryLabel: 'Retry',
                        )
                      : _selectedTab == 0
                          ? _buildWatchlists()
                          : _selectedTab == 1
                              ? _buildLiveResearch()
                              : _buildKnowledgeBase(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlists() {
    return Column(
      children: [
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

        Expanded(
          child: _watchlists.isEmpty
              ? const EmptyState(
                  icon: Icons.search,
                  title: 'Start tracking topics',
                  subtitle: 'Add topics above and JARVIS will monitor\nyour memory for relevant findings',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  itemCount: _watchlists.length,
                  itemBuilder: (context, index) {
                    final item = _watchlists[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: GlassCard(
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.science_outlined, size: 18, color: AppColors.accent),
                                tooltip: 'Research now',
                                onPressed: () => _researchTopic(item.topic),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                                onPressed: () {
                                  setState(() => _watchlists.removeAt(index));
                                  _saveWatchlists();
                                },
                              ),
                            ],
                          ),
                          children: [
                            _buildFindingsList(item),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLiveResearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  controller: _researchTopicController,
                  hintText: 'Enter a topic to research...',
                  onSubmitted: (_) => _researchTopic(_researchTopicController.text),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              GlassButton(
                onPressed: _isResearching ? null : () => _researchTopic(_researchTopicController.text),
                label: _isResearching ? 'Researching...' : 'Research',
                icon: Icons.science,
                isCompact: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          Expanded(
            child: _isResearching
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.accent),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Researching topic...\nGathering sources and generating report',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _researchError != null
                    ? ErrorState(
                        message: _researchError!,
                        onRetry: () => _researchTopic(_researchTopicController.text),
                        retryLabel: 'Retry',
                      )
                    : _lastReport != null
                        ? _buildReportView(_lastReport!)
                        : const EmptyState(
                            icon: Icons.science_outlined,
                            title: 'Start a research session',
                            subtitle: 'Enter a topic above and JARVIS will\ngather sources and generate a report',
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportView(ResearchReport report) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.article_outlined, color: AppColors.accent, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          report.topic,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    report.executiveSummary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (report.keyFindings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Key Findings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...report.keyFindings.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppColors.accent)),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],

          if (report.sections.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ...report.sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        section.content.length > 500
                            ? '${section.content.substring(0, 500)}...'
                            : section.content,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ],

          if (report.sources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sources (${report.sources.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...report.sources.take(10).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        '• ${s.title}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildKnowledgeBase() {
    return FutureBuilder<List<MemorySearchResult>>(
      future: ref.read(memorySearchProvider).getRecentMemories(limit: 30),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingState(message: 'Loading knowledge base...');
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: 'Failed to load knowledge base',
            onRetry: () => setState(() {}),
            retryLabel: 'Retry',
          );
        }

        final memories = snapshot.data ?? [];
        if (memories.isEmpty) {
          return const EmptyState(
            icon: Icons.library_books_outlined,
            title: 'Your knowledge base is empty',
            subtitle: 'Memories from conversations will appear here',
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

  Widget _buildFindingsList(_WatchlistItem item) {
    return FutureBuilder<List<MemorySearchResult>>(
      future: ref.read(memorySearchProvider).search(item.topic, limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingState(message: 'Searching...', compact: true),
          );
        }
        final findings = snapshot.data ?? [];
        if (findings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No findings yet. Tap the beaker icon to research this topic online.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: AppColors.glassBorder),
              const SizedBox(height: 8),
              ...findings.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                    Expanded(
                      child: Text(
                        f.content.length > 120 ? '${f.content.substring(0, 120)}...' : f.content,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
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
