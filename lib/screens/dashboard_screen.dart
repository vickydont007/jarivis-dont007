import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/system_service.dart';
import '../services/monitor_service.dart';
import '../models/system_info_model.dart';
import '../widgets/status_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorService>();
    final info = monitor.lastInfo;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarvis Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
            onPressed: () => monitor.start(),
          ),
        ],
      ),
      body: info == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => monitor.start(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.computer, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(info.hostname, style: theme.textTheme.titleLarge),
                          Text(info.osVersion,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Text('Uptime: ${info.uptimeHours}h',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // System metrics
                  Row(
                    children: [
                      Expanded(child: StatusCard(
                        icon: Icons.memory,
                        label: 'CPU',
                        value: '${info.cpuPercent.toStringAsFixed(1)}%',
                        progress: info.cpuUsage,
                        color: _getColor(info.cpuUsage),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: StatusCard(
                        icon: Icons.storage,
                        label: 'RAM',
                        value: '${info.memoryPercent.toStringAsFixed(1)}%',
                        subtitle: '${info.memoryUsedMB ~/ 1024}/${info.memoryTotalMB ~/ 1024} GB',
                        progress: info.memoryUsage,
                        color: _getColor(info.memoryUsage),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StatusCard(
                    icon: Icons.disc_full,
                    label: 'Disk',
                    value: '${info.diskPercent.toStringAsFixed(1)}%',
                    subtitle: '${info.diskUsedGB}/${info.diskTotalGB} GB',
                    progress: info.diskUsage,
                    color: _getColor(info.diskUsage),
                  ),
                  const SizedBox(height: 16),

                  // Quick actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quick Actions',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _quickAction(context, Icons.lock, 'Lock', () => SystemService().lockScreen()),
                              _quickAction(context, Icons.nights_stay, 'Sleep', () => SystemService().sleep()),
                              _quickAction(context, Icons.refresh, 'Restart', () => SystemService().restart()),
                              _quickAction(context, Icons.power_settings_new, 'Shut Down', () => SystemService().shutdown()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Alerts
                  Card(
                    child: StreamBuilder(
                      stream: monitor.onAlert,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(
                            leading: Icon(Icons.check_circle, color: Colors.green),
                            title: Text('All systems normal'),
                          );
                        }
                        final alert = snapshot.data as MonitorAlert;
                        return ListTile(
                          leading: Icon(Icons.warning, color: Colors.orange),
                          title: Text(alert.message),
                          subtitle: Text(alert.timestamp.toString().split('.').first),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Color _getColor(double value) {
    if (value < 0.6) return Colors.green;
    if (value < 0.8) return Colors.orange;
    return Colors.red;
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, Future<bool> Function() action) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon),
        onPressed: () => action(),
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
