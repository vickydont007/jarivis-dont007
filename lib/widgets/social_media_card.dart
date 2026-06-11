import 'package:flutter/material.dart';

class SocialMediaCard extends StatelessWidget {
  const SocialMediaCard({super.key});

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
                Icon(Icons.share, color: Colors.cyan),
                SizedBox(width: 8),
                Text(
                  'Social Media',
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
                _buildPlatformButton(
                  'Telegram',
                  Icons.telegram,
                  Colors.blue,
                  true,
                ),
                _buildPlatformButton(
                  'WhatsApp',
                  Icons.chat,
                  Colors.green,
                  false,
                ),
                _buildPlatformButton(
                  'Instagram',
                  Icons.camera_alt,
                  Colors.purple,
                  false,
                ),
                _buildPlatformButton(
                  'Facebook',
                  Icons.facebook,
                  Colors.blue[800]!,
                  false,
                ),
                _buildPlatformButton(
                  'Discord',
                  Icons.gamepad,
                  Colors.indigo,
                  true,
                ),
                _buildPlatformButton(
                  'Slack',
                  Icons.workspaces,
                  Colors.orange,
                  false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformButton(
    String platform,
    IconData icon,
    Color color,
    bool isConnected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? color.withOpacity(0.2) : const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? color : const Color(0xFF30363D),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            platform,
            style: TextStyle(
              color: isConnected ? color : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isConnected) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
