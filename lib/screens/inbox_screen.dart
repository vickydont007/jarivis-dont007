import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/glass/glass_tab_bar.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  int _selectedTab = 0;
  final List<_NotificationItem> _notifications = [];
  final List<_EmailItem> _emails = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Load from timeline and proactive engine
    try {
      final timeline = ref.read(timelineServiceProvider);
      final events = await timeline.getRecent(limit: 20);
      _notifications.clear();
      for (final event in events) {
        _notifications.add(_NotificationItem(
          title: event.title,
          body: event.description,
          time: event.timestamp,
          icon: _getIconForType(event.type.name),
          read: false,
        ));
      }

      // Add proactive insights as notifications
      try {
        final engine = ref.read(proactiveEngineProvider);
        final insights = engine.getTopInsights(limit: 5);
        for (final insight in insights) {
          _notifications.insert(0, _NotificationItem(
            title: '💡 ${insight.title}',
            body: insight.body,
            time: insight.createdAt,
            icon: _insightEmoji(insight.type.name),
            read: insight.isRead,
          ));
        }
      } catch (e) {
        // Proactive engine not ready yet
      }
    } catch (e) {
      // Use empty list
    }
    setState(() => _isLoading = false);
  }

  String _insightEmoji(String type) {
    switch (type) {
      case 'watchlist': return '🔬';
      case 'project': return '📁';
      case 'meeting': return '📅';
      case 'crossLink': return '🔗';
      default: return '💡';
    }
  }

  String _getIconForType(String type) {
    if (type.contains('agent')) return '🤖';
    if (type.contains('memory')) return '🧠';
    if (type.contains('automation')) return '⚡';
    if (type.contains('error')) return '❌';
    if (type.contains('tool')) return '🔧';
    return '📌';
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📬 Inbox',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Notifications and messages',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassButton(
                    onPressed: _loadData,
                    label: 'Refresh',
                    icon: Icons.refresh,
                    isCompact: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            GlassTabBar(
              tabs: const [
                GlassTab(label: '🔔 Notifications'),
                GlassTab(label: '📧 Email'),
              ],
              selectedIndex: _selectedTab,
              onTabChanged: (i) => setState(() => _selectedTab = i),
            ),

            const SizedBox(height: AppSpacing.xl),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _selectedTab == 0
                      ? _buildNotifications()
                      : _buildEmail(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifications() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No new notifications',
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
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              leading: Text(item.icon, style: const TextStyle(fontSize: 24)),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.read ? FontWeight.w400 : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Text(
                _formatTime(item.time),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmail() {
    if (_emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Connect your email',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add IMAP credentials in Settings to see emails here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
              onPressed: () {},
              label: 'Coming Soon',
              icon: Icons.email_outlined,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      itemCount: _emails.length,
      itemBuilder: (context, index) {
        final item = _emails[index];
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
                  item.sender[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.accent),
                ),
              ),
              title: Text(
                item.subject,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'From: ${item.sender}\n${item.preview}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _NotificationItem {
  final String title;
  final String body;
  final DateTime time;
  final String icon;
  final bool read;

  _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    this.read = false,
  });
}

class _EmailItem {
  final String sender;
  final String subject;
  final String preview;
  final DateTime time;

  _EmailItem({
    required this.sender,
    required this.subject,
    required this.preview,
    required this.time,
  });
}
