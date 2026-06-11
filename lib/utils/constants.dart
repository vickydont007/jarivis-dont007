class AppConstants {
  // App Info
  static const String appName = 'Jarvis Desktop Agent';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI-powered personal assistant with social media integration';

  // Colors
  static const int primaryColor = 0xFF00BCD4; // Cyan
  static const int backgroundColor = 0xFF0D1117;
  static const int cardColor = 0xFF161B22;
  static const int borderColor = 0xFF30363D;

  // API Endpoints
  static const String openWeatherMapBaseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String openAIBaseUrl = 'https://api.openai.com/v1';
  static const String anthropicBaseUrl = 'https://api.anthropic.com/v1';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1';

  // Social Media API Endpoints
  static const String telegramBaseUrl = 'https://api.telegram.org/bot';
  static const String discordBaseUrl = 'https://discord.com/api/v10';
  static const String slackBaseUrl = 'https://slack.com/api';

  // Storage Keys
  static const String apiKeyStorageKey = 'api_key';
  static const String aiProviderStorageKey = 'ai_provider';
  static const String voiceEnabledStorageKey = 'voice_enabled';
  static const String languageStorageKey = 'language';
  static const String weatherApiKeyStorageKey = 'weather_api_key';
  static const String defaultCityStorageKey = 'default_city';
  static const String telegramBotTokenStorageKey = 'telegram_bot_token';
  static const String discordBotTokenStorageKey = 'discord_bot_token';

  // Default Values
  static const String defaultAIProvider = 'opencode';
  static const String defaultLanguage = 'both';
  static const double defaultSpeechRate = 0.5;
  static const String defaultCity = 'New York';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration pollingInterval = Duration(seconds: 1);

  // Limits
  static const int maxMessageLength = 4096;
  static const int maxSearchResults = 10;
  static const int maxMemoryEntries = 1000;
}
