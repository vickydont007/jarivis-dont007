import 'package:flutter/material.dart';

class SystemMonitorCard extends StatefulWidget {
  const SystemMonitorCard({super.key});

  @override
  State<SystemMonitorCard> createState() => _SystemMonitorCardState();
}

class _SystemMonitorCardState extends State<SystemMonitorCard> {
  double _cpuUsage = 45.0;
  double _memoryUsage = 62.0;
  double _diskUsage = 38.0;
  double _batteryLevel = 87.0;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    // Simulate system monitoring
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _cpuUsage = 35 + (DateTime.now().millisecond % 30);
          _memoryUsage = 55 + (DateTime.now().millisecond % 20);
          _diskUsage = 38.0;
          _batteryLevel = 87.0;
        });
        _startMonitoring();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor, color: Colors.cyan),
                SizedBox(width: 8),
                Text(
                  'System Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMonitorItem(
                    'CPU',
                    _cpuUsage,
                    Icons.memory,
                    _getUsageColor(_cpuUsage),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonitorItem(
                    'Memory',
                    _memoryUsage,
                    Icons.storage,
                    _getUsageColor(_memoryUsage),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonitorItem(
                    'Disk',
                    _diskUsage,
                    Icons.storage,
                    _getUsageColor(_diskUsage),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonitorItem(
                    'Battery',
                    _batteryLevel,
                    Icons.battery_charging_full,
                    _batteryLevel > 20 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorItem(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF30363D),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value / 100,
            backgroundColor: const Color(0xFF30363D),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Color _getUsageColor(double usage) {
    if (usage < 50) return Colors.green;
    if (usage < 80) return Colors.orange;
    return Colors.red;
  }
}
