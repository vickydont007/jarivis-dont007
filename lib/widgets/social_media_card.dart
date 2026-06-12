import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialMediaCard extends ConsumerWidget {
  const SocialMediaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  context,
                  'Telegram',
                  Icons.telegram,
                  Colors.blue,
                  false,
                ),
                _buildPlatformButton(
                  context,
                  'WhatsApp',
                  Icons.chat,
                  Colors.green,
                  false,
                ),
                _buildPlatformButton(
                  context,
                  'Instagram',
                  Icons.camera_alt,
                  Colors.purple,
                  false,
                ),
                _buildPlatformButton(
                  context,
                  'Facebook',
                  Icons.facebook,
                  Colors.blue[800]!,
                  false,
                ),
                _buildPlatformButton(
                  context,
                  'Discord',
                  Icons.gamepad,
                  Colors.indigo,
                  false,
                ),
                _buildPlatformButton(
                  context,
                  'Twitter',
                  Icons.tag,
                  Colors.cyan,
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
    BuildContext context,
    String platform,
    IconData icon,
    Color color,
    bool isConnected,
  ) {
    return InkWell(
      onTap: () => _showConnectDialog(context, platform, color),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isConnected ? color.withValues(alpha: 0.2) : const Color(0xFF0D1117),
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
      ),
    );
  }

  void _showConnectDialog(BuildContext context, String platform, Color color) {
    final tokenController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            Icon(_getPlatformIcon(platform), color: color, size: 24),
            const SizedBox(width: 8),
            Text('Connect $platform', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your $platform API key or token:',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: InputDecoration(
                hintText: '$platform Token',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getInstructions(platform),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tokenController.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$platform token saved! Restart app to connect.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(context, _getSetupUrl(platform));
            },
            child: const Text('Get Token'),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'telegram':
        return Icons.telegram;
      case 'whatsapp':
        return Icons.chat;
      case 'instagram':
        return Icons.camera_alt;
      case 'facebook':
        return Icons.facebook;
      case 'discord':
        return Icons.gamepad;
      case 'twitter':
        return Icons.tag;
      default:
        return Icons.share;
    }
  }

  String _getInstructions(String platform) {
    switch (platform.toLowerCase()) {
      case 'telegram':
        return '1. Talk to @BotFather on Telegram\n2. Create a new bot\n3. Copy the API token';
      case 'discord':
        return '1. Go to discord.com/developers\n2. Create a new application\n3. Go to Bot > Copy token';
      case 'whatsapp':
        return '1. Go to business.facebook.com\n2. Set up WhatsApp Business API\n3. Get API token';
      case 'instagram':
        return '1. Go to developers.facebook.com\n2. Create Instagram app\n3. Get access token';
      case 'facebook':
        return '1. Go to developers.facebook.com\n2. Create a Facebook app\n3. Get Page access token';
      case 'twitter':
        return '1. Go to developer.twitter.com\n2. Create a project\n3. Generate API keys';
      default:
        return 'Get API token from $platform developer console';
    }
  }

  String _getSetupUrl(String platform) {
    switch (platform.toLowerCase()) {
      case 'telegram':
        return 'https://telegram.org';
      case 'discord':
        return 'https://discord.com/developers';
      case 'whatsapp':
        return 'https://business.facebook.com';
      case 'instagram':
        return 'https://developers.facebook.com';
      case 'facebook':
        return 'https://developers.facebook.com';
      case 'twitter':
        return 'https://developer.twitter.com';
      default:
        return 'https://google.com';
    }
  }

  void _launchUrl(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open $url in browser to get token'),
        backgroundColor: Colors.cyan,
      ),
    );
  }
}
