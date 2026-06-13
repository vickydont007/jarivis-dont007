import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/system_monitor_card.dart';
import '../widgets/quick_actions_card.dart';
import '../widgets/weather_card.dart';
import '../widgets/social_media_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Good Night';
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '\u{1F319}';
    if (hour < 12) return '\u{2600}\u{FE0F}';
    if (hour < 17) return '\u{26C5}';
    if (hour < 21) return '\u{1F305}';
    return '\u{1F319}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          // ── Header ──
          Row(
            children: [
              Text(
                _getGreetingEmoji(),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here's your system overview",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── System Monitor ──
          const SystemMonitorCard(),
          const SizedBox(height: 24),

          // ── Quick Actions ──
          const QuickActionsCard(),
          const SizedBox(height: 24),

          // ── Weather ──
          const WeatherCard(),
          const SizedBox(height: 24),

          // ── Social Media ──
          const SocialMediaCard(),
        ],
      ),
    );
  }
}
