import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_info2/system_info2.dart';

class SystemMonitorCard extends StatefulWidget {
  const SystemMonitorCard({super.key});

  @override
  State<SystemMonitorCard> createState() => _SystemMonitorCardState();
}

class _SystemMonitorCardState extends State<SystemMonitorCard> {
  double _memoryUsage = 0;
  double _diskUsage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStats());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    try {
      final mem = _getMemoryUsage();
      final disk = await _getDiskUsage();
      if (mounted) {
        setState(() {
          _memoryUsage = mem;
          _diskUsage = disk;
        });
      }
    } catch (e) {
      print('SystemMonitor error: $e');
    }
  }

  double _getMemoryUsage() {
    try {
      final totalMem = SysInfo.getTotalVirtualMemory();
      final freeMem = SysInfo.getFreeVirtualMemory();
      if (totalMem == 0) return 0;
      return ((totalMem - freeMem) / totalMem * 100).clamp(0.0, 100.0);
    } catch (_) {
      return 0;
    }
  }

  Future<double> _getDiskUsage() async {
    try {
      final result = await Process.run('df', ['-h', '/']);
      final lines = result.stdout.toString().split('\n');
      if (lines.length > 1) {
        final parts = lines[1].trim().split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          return double.tryParse(parts[4].replaceAll('%', '')) ?? 0;
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Color _getColor(double usage) {
    if (usage < 50) return const Color(0xFF3FB950);
    if (usage < 80) return const Color(0xFFD29922);
    return const Color(0xFFF85149);
  }

  String _getTotalMemory() {
    try {
      final bytes = SysInfo.getTotalVirtualMemory();
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(1)} GB';
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.monitor, color: Color(0xFF00BCD4), size: 20),
            SizedBox(width: 8),
            Text(
              'System Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'MEMORY',
                value: _memoryUsage,
                icon: Icons.memory,
                detail: _getTotalMemory(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'DISK',
                value: _diskUsage,
                icon: Icons.sd_storage,
                detail: '/',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required double value,
    required IconData icon,
    required String detail,
  }) {
    final color = _getColor(value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          // Circular progress
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFF30363D),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: value / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Percentage text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${value.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Label
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          // Detail
          Text(
            detail,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
