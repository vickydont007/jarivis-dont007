import 'package:flutter/material.dart';
import '../services/system_service.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

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
                Icon(Icons.flash_on, color: Colors.cyan),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  'Shutdown',
                  Icons.power_settings_new,
                  Colors.red,
                  () => _showConfirmationDialog(context, 'Shutdown', 'shutdown'),
                ),
                _buildActionButton(
                  context,
                  'Restart',
                  Icons.refresh,
                  Colors.orange,
                  () => _showConfirmationDialog(context, 'Restart', 'restart'),
                ),
                _buildActionButton(
                  context,
                  'Sleep',
                  Icons.bedtime,
                  Colors.purple,
                  () => _executeAction(context, 'sleep'),
                ),
                _buildActionButton(
                  context,
                  'Lock',
                  Icons.lock,
                  Colors.blue,
                  () => _executeAction(context, 'lock'),
                ),
                _buildActionButton(
                  context,
                  'Organize',
                  Icons.folder,
                  Colors.green,
                  () => _executeAction(context, 'organize'),
                ),
                _buildActionButton(
                  context,
                  'Weather',
                  Icons.cloud,
                  Colors.cyan,
                  () => _executeAction(context, 'weather'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, String action, String command) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Confirm $action',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to $action the system?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _executeAction(context, command);
            },
            child: Text(
              action,
              style: const TextStyle(color: Colors.red),
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
        backgroundColor: Colors.cyan,
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
        // TODO: Implement file organization
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File organization coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      case 'weather':
        // TODO: Navigate to weather
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weather view coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '$action executed successfully' : 'Failed to execute $action'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
