import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../core/services/daily_briefing_service.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/orb/animated_orb.dart';

class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  DailyBriefingReport? _report;
  bool _isLoading = true;
  bool _isEvening = false;

  @override
  void initState() {
    super.initState();
    _loadBriefing();
  }

  Future<void> _loadBriefing() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(dailyBriefingServiceProvider);
      final type = _isEvening ? BriefingType.evening : BriefingType.morning;
      final report = await service.generateBriefing(type: type);
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orbState = ref.watch(orbStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxxl, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEvening ? '🌙 Evening Recap' : '☀️ Morning Briefing',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _isEvening
                              ? 'Here\'s how your day went'
                              : 'Good ${_getGreetingPart()}, here\'s what matters',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Morning/Evening toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        _toggleButton('☀️ Morning', false),
                        _toggleButton('🌙 Evening', true),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _report == null
                      ? _buildEmptyState()
                      : _buildBriefingContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(String label, bool isEvening) {
    final isSelected = _isEvening == isEvening;
    return GestureDetector(
      onTap: () {
        setState(() => _isEvening = isEvening);
        _loadBriefing();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGhost : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnimatedOrb(state: OrbState.idle, size: 80),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Generating your briefing...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassButton(
            onPressed: _loadBriefing,
            label: 'Refresh',
            icon: Icons.refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting card
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  Text(
                    _report!.items.isNotEmpty ? _report!.items.first.icon : '👋',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _report!.greeting,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _report!.summary,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Stats row
          Row(
            children: [
              _statCard('🤖', 'Agents', '${_report!.activeAgents} active'),
              const SizedBox(width: AppSpacing.md),
              _statCard('✅', 'Tasks', '${_report!.completedTasks} done'),
              const SizedBox(width: AppSpacing.md),
              _statCard('🧠', 'Memories', '${_report!.newMemories} new'),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Activity items
          Text(
            'What happened',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          ..._report!.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: GlassCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
                ),
                leading: Text(item.icon, style: const TextStyle(fontSize: 24)),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  item.description,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )),

          // Mood summary
          if (_report!.moodSummary != null) ...[
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              variant: GlassCardVariant.accent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
                ),
                leading: const Text('💡', style: TextStyle(fontSize: 24)),
                title: Text(
                  'Overall vibe: ${_report!.moodSummary}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],

          // Proactive insights
          ..._buildProactiveInsights(),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String label, String value) {
    return Expanded(
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreetingPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  List<Widget> _buildProactiveInsights() {
    try {
      final engine = ref.read(proactiveEngineProvider);
      final insights = engine.getTopInsights(limit: 3);
      if (insights.isEmpty) return [];

      return [
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Proactive Insights',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              leading: Text(
                _insightEmoji(insight.type.name),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(
                insight.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                insight.body.length > 100
                    ? '${insight.body.substring(0, 100)}...'
                    : insight.body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        )),
      ];
    } catch (e) {
      return [];
    }
  }

  String _insightEmoji(String type) {
    switch (type) {
      case 'watchlist': return '🔬';
      case 'project': return '📁';
      case 'meeting': return '📅';
      case 'crossLink': return '🔗';
      case 'system': return '⚙️';
      default: return '💡';
    }
  }
}
