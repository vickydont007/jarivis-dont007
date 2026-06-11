import '../core/logger.dart';
import 'terminal_service.dart';

class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  final JarvisLogger _log = JarvisLogger();
  final TerminalService _terminal = TerminalService();
  String _lastContent = '';

  Future<String> get() async {
    final result = await _terminal.run(
      'powershell -Command "Get-Clipboard"',
      timeout: 5000,
    );
    return result.success ? result.stdout.trim() : '';
  }

  Future<bool> set(String text) async {
    final result = await _terminal.run(
      'powershell -Command "Set-Clipboard -Value \'$text\'"',
      timeout: 5000,
    );
    return result.success;
  }

  Future<String?> watch({int intervalMs = 1000}) async {
    final current = await get();
    if (current != _lastContent && current.isNotEmpty) {
      _lastContent = current;
      return current;
    }
    return null;
  }

  void startWatching() {
    _lastContent = '';
  }

  Future<void> append(String text) async {
    final current = await get();
    await set('$current\n$text');
  }

  Future<void> clear() async {
    await set('');
  }
}
