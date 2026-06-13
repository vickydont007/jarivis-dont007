import 'package:flutter/material.dart';
import '../services/system_service.dart';
import '../services/file_service.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, color: Color(0xFF00BCD4), size: 20),
            SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _buildTile(
              context,
              'Sleep',
              Icons.bedtime_rounded,
              const Color(0xFFA855F7),
              () => _executeAction(context, 'sleep'),
            ),
            _buildTile(
              context,
              'Lock',
              Icons.lock_outline_rounded,
              const Color(0xFF3B82F6),
              () => _executeAction(context, 'lock'),
            ),
            _buildTile(
              context,
              'Organize',
              Icons.folder_open_rounded,
              const Color(0xFF22C55E),
              () => _executeAction(context, 'organize'),
            ),
            _buildTile(
              context,
              'Restart',
              Icons.restart_alt_rounded,
              const Color(0xFFF97316),
              () => _showConfirmationDialog(context, 'Restart', 'restart'),
            ),
            _buildTile(
              context,
              'Shutdown',
              Icons.power_settings_new_rounded,
              const Color(0xFFEF4444),
              () => _showConfirmationDialog(context, 'Shutdown', 'shutdown'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, String action, String command) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: Text(
          'Confirm $action',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to $action?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _executeAction(context, command);
            },
            child: Text(
              action,
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _executeAction(BuildContext context, String action) async {
    final systemService = SystemService();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Executing $action...'),
        backgroundColor: const Color(0xFF00BCD4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    bool success = false;
    switch (action) {
      case 'shutdown':
        success = await systemService.shutdown();
        break;
      case 'restart':
        success = await systemService.restart();
        break;
      case 'sleep':
        success = await systemService.sleep();
        break;
      case 'lock':
        success = await systemService.lock();
        break;
      case 'organize':
        try {
          final fileService = FileService();
          final results = await fileService.organizeDownloads();
          final total = results.values.fold<int>(0, (sum, count) => sum + count);
          if (total == 0) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Downloads folder is already organized!'),
                  backgroundColor: const Color(0xFF22C55E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }
          } else {
            final details = results.entries
                .where((e) => e.value > 0)
                .map((e) => '${e.key}: ${e.value}')
                .join(', ');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Organized $total files: $details'),
                  backgroundColor: const Color(0xFF22C55E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Organize failed: $e'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        }
        return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '$action executed successfully' : 'Failed to execute $action'),
          backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}
