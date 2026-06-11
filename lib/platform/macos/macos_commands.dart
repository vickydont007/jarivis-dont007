import 'dart:io';
import '../../services/terminal_service.dart';

class MacosCommands {
  final TerminalService _terminal = TerminalService();

  // === System ===
  Future<bool> shutdown({int delayMin = 0}) async {
    final r = await _terminal.run(delayMin > 0 
        ? 'sudo shutdown -h +$delayMin'
        : 'sudo shutdown -h now');
    return r.success;
  }

  Future<bool> restart({int delayMin = 0}) async {
    final r = await _terminal.run(delayMin > 0
        ? 'sudo shutdown -r +$delayMin'
        : 'sudo shutdown -r now');
    return r.success;
  }

  Future<bool> sleep() async {
    final r = await _terminal.run('pmset sleepnow');
    return r.success;
  }

  Future<bool> lock() async {
    final r = await _terminal.run(
      '/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend'
    );
    return r.success;
  }

  // === Apps ===
  Future<bool> openApp(String name) async {
    final r = await _terminal.run('open -a "$name"');
    return r.success;
  }

  Future<bool> killApp(String name) async {
    final r = await _terminal.run('pkill -x "$name" 2>/dev/null || true');
    return r.success;
  }

  Future<List<String>> listApps() async {
    final r = await _terminal.run(
      'ls /Applications/ | head -30'
    );
    return r.success ? r.stdout.split('\n').where((s) => s.isNotEmpty).toList() : [];
  }

  // === Files ===
  Future<String> getDownloadsPath() async {
    final r = await _terminal.run('echo \$HOME/Downloads');
    return r.success ? r.stdout.trim() : '/Users/Default/Downloads';
  }

  Future<bool> emptyTrash() async {
    final r = await _terminal.run('sudo rm -rf ~/.Trash/* 2>/dev/null; true');
    return r.success;
  }

  // === Network ===
  Future<String> getLocalIp() async {
    final r = await _terminal.run(
      "ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print \$2}' | head -1"
    );
    return r.success ? r.stdout.trim() : 'Unknown';
  }

  Future<bool> toggleWiFi({bool? on}) async {
    final state = on == true ? 'on' : 'off';
    final r = await _terminal.run('networksetup -setairportpower en0 $state');
    return r.success;
  }

  // === macOS-Specific ===
  Future<bool> setVolume(int percent) async {
    final clamped = percent.clamp(0, 100).toDouble() / 100;
    final r = await _terminal.run('osascript -e "set volume output volume $clamped"');
    return r.success;
  }

  Future<String> getActiveApp() async {
    final r = await _terminal.run(
      'osascript -e \'tell application "System Events" to get name of first application process whose frontmost is true\''
    );
    return r.success ? r.stdout.trim() : 'Unknown';
  }

  Future<bool> runShortcut(String shortcutName) async {
    final r = await _terminal.run('shortcuts run "$shortcutName"');
    return r.success;
  }

  // === Clipboard ===
  Future<String> getClipboard() async {
    final r = await _terminal.run('pbpaste');
    return r.success ? r.stdout.trim() : '';
  }

  Future<bool> setClipboard(String text) async {
    final r = await _terminal.run('echo "$text" | pbcopy');
    return r.success;
  }

  // === Finder ===
  Future<bool> openFinder(String path) async {
    final r = await _terminal.run('open "$path"');
    return r.success;
  }

  Future<bool> showDesktop() async {
    final r = await _terminal.run(
      'osascript -e \'tell application "Finder" to activate\' -e \'tell application "System Events" to key code 103\''
    );
    return r.success;
  }
}
