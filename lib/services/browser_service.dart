import '../core/logger.dart';
import '../core/platform.dart';
import 'terminal_service.dart';

class BrowserService {
  static final BrowserService _instance = BrowserService._internal();
  factory BrowserService() => _instance;
  BrowserService._internal();

  final JarvisLogger _log = JarvisLogger();
  final TerminalService _terminal = TerminalService();

  Future<bool> openUrl(String url) async {
    final cmd = PlatformInfo.isWindows
        ? 'Start-Process "$url"'
        : 'open "$url"';
    final result = await _terminal.run(cmd);
    return result.success;
  }

  Future<String> getActiveTabUrl() async {
    // Platform-specific methods to get current browser URL
    if (PlatformInfo.isMacOS) {
      // macOS: use AppleScript to get frontmost browser URL
      final script = '''
tell application "System Events"
  set frontApp to name of first application process whose frontmost is true
end tell
if frontApp contains "Chrome" then
  tell application "Google Chrome" to get URL of active tab of front window
else if frontApp contains "Safari" then
  tell application "Safari" to get URL of current tab of front window
else if frontApp contains "Edge" then
  tell application "Microsoft Edge" to get URL of active tab of front window
end if
''';
      final result = await _terminal.run('osascript -e \'$script\'');
      if (result.success) return result.stdout.trim();
    }
    return 'Not supported on this platform';
  }

  Future<bool> openNewTab(String url, {String? browser}) async {
    if (PlatformInfo.isMacOS) {
      final app = browser ?? 'Google Chrome';
      final script = '''
tell application "$app"
  activate
  tell front window to make new tab with properties {URL:"$url"}
end tell
''';
      final result = await _terminal.run('osascript -e \'$script\'');
      return result.success;
    }
    // Windows fallback
    return openUrl(url);
  }

  Future<String> getPageContent(String url) async {
    // Simple curl-based extraction
    final cmd = PlatformInfo.isWindows
        ? 'curl -s -L "$url" 2> nul'
        : 'curl -s -L "$url" 2>/dev/null';
    final result = await _terminal.run(cmd, timeout: 15000);
    return result.success ? result.stdout : 'Failed to fetch $url';
  }

  Future<List<String>> getOpenTabs({String? browser}) async {
    if (PlatformInfo.isMacOS) {
      final app = browser ?? 'Google Chrome';
      if (app.contains('Chrome') || app.contains('Edge')) {
        final result = await _terminal.run('''
osascript -e '
tell application "$app"
  set tabList to {}
  repeat with w in windows
    repeat with t in tabs of w
      set end of tabList to (URL of t) & " | " & (title of t)
    end repeat
  end repeat
  return tabList
end tell'
''');
        if (result.success) {
          return result.stdout
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    }
    return ['Browser tab listing not supported on this platform'];
  }
}
