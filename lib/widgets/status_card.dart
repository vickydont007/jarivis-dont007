import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final double progress;
  final Color color;

  const StatusCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.progress,
    this.color = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: color)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
