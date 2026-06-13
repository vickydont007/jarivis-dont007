import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialMediaCard extends ConsumerWidget {
  const SocialMediaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF00BCD4), size: 20),
            SizedBox(width: 8),
            Text(
              'Connected Apps',
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
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _buildPlatformCard(context, 'Telegram', Icons.telegram, const Color(0xFF0088CC), false),
            _buildPlatformCard(context, 'WhatsApp', Icons.chat_rounded, const Color(0xFF25D366), false),
            _buildPlatformCard(context, 'Instagram', Icons.camera_alt_rounded, const Color(0xFFE4405F), false),
            _buildPlatformCard(context, 'Facebook', Icons.facebook_rounded, const Color(0xFF1877F2), false),
            _buildPlatformCard(context, 'Discord', Icons.gamepad_rounded, const Color(0xFF5865F2), false),
            _buildPlatformCard(context, 'Twitter', Icons.tag, const Color(0xFF1DA1F2), false),
          ],
        ),
      ],
    );
  }

  Widget _buildPlatformCard(
    BuildContext context,
    String platform,
    IconData icon,
    Color color,
    bool isConnected,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showConnectDialog(context, platform, color),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            children: [
              // Colored left border
              Container(
                width: 4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color: isConnected ? const Color(0xFF3FB950) : const Color(0xFF6E7681),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Status dot
              if (isConnected)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3FB950),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getPlatformIcon(platform), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Connect $platform', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your $platform API key or token:',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: InputDecoration(
                hintText: '$platform Token',
                hintStyle: const TextStyle(color: Color(0xFF6E7681)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getInstructions(platform),
              style: const TextStyle(color: Color(0xFF6E7681), fontSize: 11, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              if (tokenController.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$platform token saved! Restart app to connect.'),
                    backgroundColor: const Color(0xFF22C55E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Open ${_getSetupUrl(platform)} in browser'),
                  backgroundColor: const Color(0xFF00BCD4),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Get Token'),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'telegram': return Icons.telegram;
      case 'whatsapp': return Icons.chat_rounded;
      case 'instagram': return Icons.camera_alt_rounded;
      case 'facebook': return Icons.facebook_rounded;
      case 'discord': return Icons.gamepad_rounded;
      case 'twitter': return Icons.tag;
      default: return Icons.share;
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
      case 'telegram': return 'https://telegram.org';
      case 'discord': return 'https://discord.com/developers';
      case 'whatsapp': return 'https://business.facebook.com';
      case 'instagram': return 'https://developers.facebook.com';
      case 'facebook': return 'https://developers.facebook.com';
      case 'twitter': return 'https://developer.twitter.com';
      default: return 'https://google.com';
    }
  }
}
