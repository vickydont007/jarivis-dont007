class AppConstants {
  static const String appName = 'Jarvis Desktop Agent';
  static const String appVersion = '1.0.0';
  static const String appAuthor = 'Jarvis AI';
  
  // Hermes WebSocket connection
  static const String hermesDefaultHost = 'localhost';
  static const int hermesDefaultPort = 8765;
  static const String hermesDefaultUrl = 'ws://$hermesDefaultHost:$hermesDefaultPort/ws';
  
  // Timeouts (in milliseconds)
  static const int commandTimeout = 30000;        // 30s for commands
  static const int terminalTimeout = 60000;       // 60s for terminal
  static const int connectTimeout = 10000;        // 10s for WS connect
  static const int reconnectDelay = 5000;         // 5s delay reconnect
  
  // Scheduling
  static const int maxScheduledTasks = 50;
  static const int schedulerCheckInterval = 30;  // seconds
  
  // Monitoring interval
  static const int monitorInterval = 5;            // seconds
  
  // File settings
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const int cleanupAgeDays = 30;            // files older than 30 days
  
  // UI
  static const double sidebarWidth = 250;
  static const double cardBorderRadius = 12;
}
