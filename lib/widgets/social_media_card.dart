import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';

class SocialMediaCard extends ConsumerWidget {
  const SocialMediaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final socialManager = appState.socialManager;

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
            _buildPlatformCard(context, ref, 'Telegram', Icons.telegram, const Color(0xFF0088CC), socialManager?.isPlatformConnected('telegram') ?? false),
            _buildPlatformCard(context, ref, 'WhatsApp', Icons.chat_rounded, const Color(0xFF25D366), socialManager?.isPlatformConnected('whatsapp') ?? false),
            _buildPlatformCard(context, ref, 'Instagram', Icons.camera_alt_rounded, const Color(0xFFE4405F), socialManager?.isPlatformConnected('instagram') ?? false),
            _buildPlatformCard(context, ref, 'Facebook', Icons.facebook_rounded, const Color(0xFF1877F2), socialManager?.isPlatformConnected('facebook') ?? false),
            _buildPlatformCard(context, ref, 'Discord', Icons.gamepad_rounded, const Color(0xFF5865F2), socialManager?.isPlatformConnected('discord') ?? false),
            _buildPlatformCard(context, ref, 'Twitter', Icons.tag, const Color(0xFF1DA1F2), false),
          ],
        ),
      ],
    );
  }

  Widget _buildPlatformCard(BuildContext context, WidgetRef ref, String platform, IconData icon, Color color, bool isConnected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showConnectDialog(context, ref, platform, color),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isConnected ? color.withValues(alpha: 0.4) : const Color(0xFF30363D)),
          ),
          child: Row(
            children: [
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
                      isConnected ? 'Connected' : 'Tap to connect',
                      style: TextStyle(
                        color: isConnected ? const Color(0xFF3FB950) : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
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

  void _showConnectDialog(BuildContext context, WidgetRef ref, String platform, Color color) {
    switch (platform) {
      case 'Facebook':
        _showFacebookDialog(context, ref, color);
        break;
      case 'Instagram':
        _showInstagramDialog(context, ref, color);
        break;
      case 'WhatsApp':
        _showWhatsAppDialog(context, ref, color);
        break;
      case 'Telegram':
        _showTelegramDialog(context, ref, color);
        break;
      case 'Discord':
        _showDiscordDialog(context, ref, color);
        break;
      default:
        _showGenericDialog(context, platform, color);
    }
  }

  void _showFacebookDialog(BuildContext context, WidgetRef ref, Color color) {
    final tokenController = TextEditingController();
    final pageIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 18)),
          const SizedBox(width: 12),
          const Text('Connect Facebook', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: tokenController, style: const TextStyle(color: Colors.white), obscureText: true, decoration: InputDecoration(hintText: 'Page Access Token (EAAxxx...)', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          TextField(controller: pageIdController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Page ID (123456789)', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          Text('1. Go to developers.facebook.com\n2. Create a Facebook Page app\n3. Generate Page Access Token\n4. Copy Page ID from Page Settings', style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () async {
              if (tokenController.text.isNotEmpty && pageIdController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('facebook_access_token', tokenController.text.trim());
                await prefs.setString('facebook_page_id', pageIdController.text.trim());
                final socialManager = ref.read(appStateProvider).socialManager;
                socialManager?.setupFacebook(accessToken: tokenController.text.trim(), pageId: pageIdController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Facebook connected!'), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showInstagramDialog(BuildContext context, WidgetRef ref, Color color) {
    final tokenController = TextEditingController();
    final pageIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE4405F), size: 18)),
          const SizedBox(width: 12),
          const Text('Connect Instagram', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: tokenController, style: const TextStyle(color: Colors.white), obscureText: true, decoration: InputDecoration(hintText: 'Access Token', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          TextField(controller: pageIdController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Page ID', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          Text('1. Go to developers.facebook.com\n2. Create Instagram app\n3. Get access token', style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () async {
              if (tokenController.text.isNotEmpty && pageIdController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('instagram_access_token', tokenController.text.trim());
                await prefs.setString('instagram_page_id', pageIdController.text.trim());
                final socialManager = ref.read(appStateProvider).socialManager;
                socialManager?.setupInstagram(accessToken: tokenController.text.trim(), pageId: pageIdController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Instagram connected!'), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppDialog(BuildContext context, WidgetRef ref, Color color) {
    final tokenController = TextEditingController();
    final phoneIdController = TextEditingController();
    final businessIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18)),
          const SizedBox(width: 12),
          const Text('Connect WhatsApp', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: tokenController, style: const TextStyle(color: Colors.white), obscureText: true, decoration: InputDecoration(hintText: 'Access Token', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          TextField(controller: phoneIdController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Phone Number ID', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          TextField(controller: businessIdController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Business Account ID', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          Text('1. Go to business.facebook.com\n2. Set up WhatsApp Business API\n3. Get all 3 values from dashboard', style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () async {
              if (tokenController.text.isNotEmpty && phoneIdController.text.isNotEmpty && businessIdController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('whatsapp_access_token', tokenController.text.trim());
                await prefs.setString('whatsapp_phone_number_id', phoneIdController.text.trim());
                await prefs.setString('whatsapp_business_account_id', businessIdController.text.trim());
                final socialManager = ref.read(appStateProvider).socialManager;
                socialManager?.setupWhatsApp(accessToken: tokenController.text.trim(), phoneNumberId: phoneIdController.text.trim(), businessAccountId: businessIdController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('WhatsApp connected!'), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showTelegramDialog(BuildContext context, WidgetRef ref, Color color) {
    final tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 18)),
          const SizedBox(width: 12),
          const Text('Connect Telegram', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: tokenController, style: const TextStyle(color: Colors.white), obscureText: true, decoration: InputDecoration(hintText: 'Bot Token', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          Text('1. Talk to @BotFather on Telegram\n2. Create a new bot\n3. Copy the API token', style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () async {
              if (tokenController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('telegram_bot_token', tokenController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Telegram token saved! Restart app.'), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDiscordDialog(BuildContext context, WidgetRef ref, Color color) {
    final tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.gamepad_rounded, color: Color(0xFF5865F2), size: 18)),
          const SizedBox(width: 12),
          const Text('Connect Discord', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: tokenController, style: const TextStyle(color: Colors.white), obscureText: true, decoration: InputDecoration(hintText: 'Bot Token', hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: const Color(0xFF0D1117), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF30363D))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BCD4))))),
          const SizedBox(height: 12),
          Text('1. Go to discord.com/developers\n2. Create a new application\n3. Go to Bot > Copy token', style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () async {
              if (tokenController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('discord_bot_token', tokenController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Discord token saved! Restart app.'), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showGenericDialog(BuildContext context, String platform, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF30363D))),
        title: Text('Connect $platform', style: const TextStyle(color: Colors.white)),
        content: Text('Go to Settings to configure $platform.', style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF00BCD4)))),
        ],
      ),
    );
  }
}
