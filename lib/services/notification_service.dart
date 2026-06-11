import 'dart:io';
import '../core/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final JarvisLogger _log = JarvisLogger();

  Future<bool> show(String title, String body) async {
    try {
      if (Platform.isMacOS) {
        return _macNotification(title, body);
      } else if (Platform.isWindows) {
        return _windowsNotification(title, body);
      }
      _log.warning('Notifications not supported on this platform');
      return false;
    } catch (e) {
      _log.error('Notification failed', exception: e);
      return false;
    }
  }

  Future<bool> _macNotification(String title, String body) async {
    final script = '''
display notification "$body" with title "$title" sound name "default"
''';
    final process = await Process.start(
      'osascript',
      ['-e', script],
    );
    await process.exitCode;
    return true;
  }

  Future<bool> _windowsNotification(String title, String body) async {
    // Using PowerShell toast notification
    final psScript = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
\$textNodes = \$template.GetElementsByTagName("text")
\$textNodes.Item(0).AppendChild(\$template.CreateTextNode("$title")) > \$null
\$textNodes.Item(1).AppendChild(\$template.CreateTextNode("$body")) > \$null
\$toast = [Windows.UI.Notifications.ToastNotification]\$template
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Jarvis Agent").Show(\$toast)
''';
    final process = await Process.start(
      'powershell',
      ['-NoProfile', '-Command', psScript],
      runInShell: true,
    );
    await process.exitCode;
    return true;
  }
}
