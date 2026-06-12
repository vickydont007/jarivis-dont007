import 'dart:async';
import 'dart:collection';
import 'telegram_service.dart';
import 'discord_service.dart';
import 'whatsapp_service.dart';
import 'instagram_service.dart';
import 'facebook_service.dart';

enum SocialPlatform {
  telegram,
  discord,
  whatsapp,
  instagram,
  facebook,
}

class SocialMessage {
  final String id;
  final SocialPlatform platform;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  SocialMessage({
    required this.id,
    required this.platform,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.metadata = const {},
  });
}

class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _requests = Queue<DateTime>();

  RateLimiter({this.maxRequests = 30, this.window = const Duration(seconds: 1)});

  bool get canProceed {
    final now = DateTime.now();
    while (_requests.isNotEmpty && _requests.first.difference(now).abs() > window) {
      _requests.removeFirst();
    }
    return _requests.length < maxRequests;
  }

  void record() {
    _requests.add(DateTime.now());
  }
}

class SocialManager {
  final TelegramService _telegram = TelegramService();
  final DiscordService _discord = DiscordService();
  final WhatsAppService _whatsapp = WhatsAppService();
  final InstagramService _instagram = InstagramService();
  final FacebookService _facebook = FacebookService();

  final Map<SocialPlatform, RateLimiter> _rateLimiters = {};
  final Queue<SocialMessage> _messageQueue = Queue<SocialMessage>();
  final StreamController<SocialMessage> _messageController =
      StreamController<SocialMessage>.broadcast();

  final Map<SocialPlatform, bool> _connectedPlatforms = {};

  Stream<SocialMessage> get messageStream => _messageController.stream;
  Map<SocialPlatform, bool> get connectedPlatforms => Map.unmodifiable(_connectedPlatforms);

  SocialManager() {
    // Initialize rate limiters for each platform
    _rateLimiters[SocialPlatform.telegram] = RateLimiter(maxRequests: 30);
    _rateLimiters[SocialPlatform.discord] = RateLimiter(maxRequests: 50, window: const Duration(seconds: 5));
    _rateLimiters[SocialPlatform.whatsapp] = RateLimiter(maxRequests: 80, window: const Duration(seconds: 60));
    _rateLimiters[SocialPlatform.instagram] = RateLimiter(maxRequests: 200, window: const Duration(hours: 1));
    _rateLimiters[SocialPlatform.facebook] = RateLimiter(maxRequests: 200, window: const Duration(hours: 1));

    // Initialize connection status
    for (final platform in SocialPlatform.values) {
      _connectedPlatforms[platform] = false;
    }

    // Listen to platform messages
    _setupMessageListeners();
  }

  void _setupMessageListeners() {
    _telegram.messageStream.listen((msg) {
      _onMessage(SocialPlatform.telegram, 'telegram_${msg.chatId}', 'User', msg.text);
    });

    _discord.messageStream.listen((msg) {
      _onMessage(SocialPlatform.discord, msg.channelId, msg.authorUsername ?? 'Discord User', msg.content);
    });

    _whatsapp.messageStream.listen((msg) {
      _onMessage(SocialPlatform.whatsapp, msg.from, 'WhatsApp User', msg.text);
    });

    _instagram.messageStream.listen((msg) {
      _onMessage(SocialPlatform.instagram, msg.senderId, 'Instagram User', msg.text);
    });

    _facebook.messageStream.listen((msg) {
      _onMessage(SocialPlatform.facebook, msg.senderId, 'Facebook User', msg.text);
    });
  }

  void _onMessage(SocialPlatform platform, String senderId, String senderName, String content) {
    final message = SocialMessage(
      id: '${platform.name}_${DateTime.now().millisecondsSinceEpoch}',
      platform: platform,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
    );
    _messageController.add(message);
  }

  // Platform setup
  void setupTelegram(String botToken) {
    _telegram.setBotToken(botToken);
    _telegram.initialize();
    _connectedPlatforms[SocialPlatform.telegram] = true;
  }

  void setupDiscord(String botToken) {
    _discord.setBotToken(botToken);
    _discord.connect();
    _connectedPlatforms[SocialPlatform.discord] = true;
  }

  void setupWhatsApp({
    required String accessToken,
    required String phoneNumberId,
    required String businessAccountId,
    String? verifyToken,
  }) {
    _whatsapp.setCredentials(
      accessToken: accessToken,
      phoneNumberId: phoneNumberId,
      businessAccountId: businessAccountId,
      verifyToken: verifyToken,
    );
    _connectedPlatforms[SocialPlatform.whatsapp] = true;
  }

  void setupInstagram({
    required String accessToken,
    required String pageId,
  }) {
    _instagram.setCredentials(
      accessToken: accessToken,
      pageId: pageId,
    );
    _connectedPlatforms[SocialPlatform.instagram] = true;
  }

  void setupFacebook({
    required String accessToken,
    required String pageId,
  }) {
    _facebook.setCredentials(
      accessToken: accessToken,
      pageId: pageId,
    );
    _connectedPlatforms[SocialPlatform.facebook] = true;
  }

  // Send message with rate limiting
  Future<bool> sendMessage(SocialPlatform platform, String recipientId, String content) async {
    if (!_connectedPlatforms[platform]!) {
      _messageQueue.add(SocialMessage(
        id: 'queued_${DateTime.now().millisecondsSinceEpoch}',
        platform: platform,
        senderId: 'system',
        senderName: 'Nextron',
        content: content,
        timestamp: DateTime.now(),
        metadata: {'recipient': recipientId, 'queued': true},
      ));
      return false;
    }

    final rateLimiter = _rateLimiters[platform]!;
    if (!rateLimiter.canProceed) {
      // Queue message for later
      _messageQueue.add(SocialMessage(
        id: 'queued_${DateTime.now().millisecondsSinceEpoch}',
        platform: platform,
        senderId: 'system',
        senderName: 'Nextron',
        content: content,
        timestamp: DateTime.now(),
        metadata: {'recipient': recipientId, 'queued': true},
      ));
      return false;
    }

    rateLimiter.record();

    try {
      switch (platform) {
        case SocialPlatform.telegram:
          return await _telegram.sendMessage(int.parse(recipientId), content);
        case SocialPlatform.discord:
          return await _discord.sendMessage(recipientId, content);
        case SocialPlatform.whatsapp:
          return await _whatsapp.sendMessage(recipientId, content);
        case SocialPlatform.instagram:
          return await _instagram.sendMessage(recipientId, content);
        case SocialPlatform.facebook:
          return await _facebook.sendMessage(recipientId, content);
      }
    } catch (e) {
      print('Error sending message to $platform: $e');
      return false;
    }
  }

  // Send to all connected platforms
  Future<Map<SocialPlatform, bool>> broadcastMessage(String content) async {
    final results = <SocialPlatform, bool>{};

    for (final platform in SocialPlatform.values) {
      if (_connectedPlatforms[platform]!) {
        // Would need a default recipient for each platform
        results[platform] = false;
      }
    }

    return results;
  }

  // Process queued messages
  Future<void> processQueue() async {
    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.first;
      final rateLimiter = _rateLimiters[message.platform]!;

      if (rateLimiter.canProceed && _connectedPlatforms[message.platform]!) {
        _messageQueue.removeFirst();
        final recipient = message.metadata['recipient'] as String;
        await sendMessage(message.platform, recipient, message.content);
      } else {
        break; // Wait for rate limit to reset
      }
    }
  }

  // Get queue status
  Map<SocialPlatform, int> getQueueStatus() {
    final status = <SocialPlatform, int>{};
    for (final platform in SocialPlatform.values) {
      status[platform] = _messageQueue.where((m) => m.platform == platform).length;
    }
    return status;
  }

  // Get connected platforms
  List<SocialPlatform> getConnectedPlatforms() {
    return _connectedPlatforms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  // Disconnect platform
  void disconnect(SocialPlatform platform) {
    _connectedPlatforms[platform] = false;
    switch (platform) {
      case SocialPlatform.telegram:
        // Telegram doesn't have explicit disconnect
        break;
      case SocialPlatform.discord:
        _discord.dispose();
        break;
      case SocialPlatform.whatsapp:
        // WhatsApp doesn't have explicit disconnect
        break;
      case SocialPlatform.instagram:
        // Instagram doesn't have explicit disconnect
        break;
      case SocialPlatform.facebook:
        // Facebook doesn't have explicit disconnect
        break;
    }
  }

  // Get stats
  Map<String, dynamic> getStats() {
    return {
      'connected_platforms': getConnectedPlatforms().length,
      'total_platforms': SocialPlatform.values.length,
      'queued_messages': _messageQueue.length,
      'queue_by_platform': getQueueStatus(),
    };
  }

  void dispose() {
    _messageController.close();
    _telegram.dispose();
    _discord.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _facebook.dispose();
  }
}
