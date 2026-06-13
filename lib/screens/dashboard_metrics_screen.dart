import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';
import '../core/real_time_monitor.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;
  SystemMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    final appState = ref.read(appStateProvider);
    final toolManager = appState.toolManager;

    if (toolManager != null) {
      setState(() {
        _metrics = toolManager.monitor.getMetrics();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildActivityFeed(),
            const SizedBox(height: 24),
            _buildCostBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.dashboard,
            color: Color(0xFF00BCD4),
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Real-time system metrics and activity',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh, color: Colors.grey),
      onPressed: _refreshData,
      tooltip: 'Refresh',
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Tool Calls',
          '${_metrics?.totalToolCalls ?? 0}',
          Icons.build,
          const Color(0xFF00BCD4),
        ),
        _buildMetricCard(
          'Active Agents',
          '${_metrics?.activeAgents ?? 0}',
          Icons.smart_toy,
          const Color(0xFF4CAF50),
        ),
        _buildMetricCard(
          'Completed Tasks',
          '${_metrics?.completedTasks ?? 0}',
          Icons.check_circle,
          const Color(0xFF8BC34A),
        ),
        _buildMetricCard(
          'Success Rate',
          '${((_metrics?.successRate ?? 0) * 100).toStringAsFixed(1)}%',
          Icons.trending_up,
          const Color(0xFFFF9800),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    final appState = ref.read(appStateProvider);
    final activities = appState.toolManager?.monitor.getRecentActivities(limit: 10) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFF00BCD4), size: 20),
              SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            const Center(
              child: Text(
                'No recent activity',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...activities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityEvent activity) {
    final icon = _getActivityIcon(activity.type);
    final color = _getActivityColor(activity.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${activity.source} • ${_formatTime(activity.timestamp)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdown() {
    final appState = ref.read(appStateProvider);
    final costTracker = appState.toolManager?.costTracker;

    return FutureBuilder(
      future: costTracker?.getTodaySummary(),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.attach_money, color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Today\'s Usage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCostMetric('Total Cost', '\$${(summary?.totalCost ?? 0).toStringAsFixed(4)}'),
                  _buildCostMetric('Total Tokens', '${summary?.totalTokens ?? 0}'),
                  _buildCostMetric('Requests', '${summary?.totalRequests ?? 0}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCostMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.toolCall:
        return Icons.build;
      case ActivityType.agentSpawn:
        return Icons.add_circle;
      case ActivityType.agentKill:
        return Icons.remove_circle;
      case ActivityType.taskRouted:
        return Icons.alt_route;
      case ActivityType.taskCompleted:
        return Icons.check_circle;
      case ActivityType.taskFailed:
        return Icons.error;
      case ActivityType.memoryAdded:
        return Icons.memory;
      case ActivityType.memorySearched:
        return Icons.search;
      case ActivityType.codeExecuted:
        return Icons.code;
      case ActivityType.systemEvent:
        return Icons.settings;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.toolCall:
        return const Color(0xFF00BCD4);
      case ActivityType.agentSpawn:
        return const Color(0xFF4CAF50);
      case ActivityType.agentKill:
        return const Color(0xFFF44336);
      case ActivityType.taskRouted:
        return const Color(0xFF2196F3);
      case ActivityType.taskCompleted:
        return const Color(0xFF8BC34A);
      case ActivityType.taskFailed:
        return const Color(0xFFFF5722);
      case ActivityType.memoryAdded:
        return const Color(0xFF9C27B0);
      case ActivityType.memorySearched:
        return const Color(0xFFE91E63);
      case ActivityType.codeExecuted:
        return const Color(0xFFFF9800);
      case ActivityType.systemEvent:
        return const Color(0xFF607D8B);
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
