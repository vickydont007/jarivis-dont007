import 'dart:io';
import '../../services/terminal_service.dart';

class WindowsCommands {
  final TerminalService _terminal = TerminalService();

  // === System ===
  Future<bool> shutdown({int delay = 0}) async {
    final r = await _terminal.run('shutdown /s /t $delay');
    return r.success;
  }

  Future<bool> restart({int delay = 0}) async {
    final r = await _terminal.run('shutdown /r /t $delay');
    return r.success;
  }

  Future<bool> sleep() async {
    final r = await _terminal.run('rundll32.exe powrprof.dll,SetSuspendState 0,1,0');
    return r.success;
  }

  Future<bool> lock() async {
    final r = await _terminal.run('rundll32.exe user32.dll,LockWorkStation');
    return r.success;
  }

  // === Apps ===
  Future<bool> openApp(String name) async {
    final r = await _terminal.run('Start-Process "$name"');
    return r.success;
  }

  Future<bool> killApp(String name) async {
    final r = await _terminal.run('Stop-Process -Name "$name" -Force -ErrorAction SilentlyContinue');
    return r.success;
  }

  // === Files ===
  Future<String> getDownloadsPath() async {
    final r = await _terminal.run('[Environment]::GetFolderPath("MyDocuments")');
    return r.success ? r.stdout.trim() : 'C:\\Users\\Default\\Downloads';
  }

  Future<bool> emptyRecycleBin() async {
    final r = await _terminal.run('Clear-RecycleBin -Force -ErrorAction SilentlyContinue');
    return r.success;
  }

  // === Network ===
  Future<String> getLocalIp() async {
    final r = await _terminal.run(
      '(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress | Select-Object -First 1'
    );
    return r.success ? r.stdout.trim() : 'Unknown';
  }

  Future<bool> resetNetwork() async {
    final r = await _terminal.run('ipconfig /flushdns');
    return r.success;
  }

  // === Clipboard ===
  Future<String> getClipboard() async {
    final r = await _terminal.run('Get-Clipboard');
    return r.success ? r.stdout.trim() : '';
  }

  Future<bool> setClipboard(String text) async {
    final r = await _terminal.run('Set-Clipboard -Value "$text"');
    return r.success;
  }

  // === Windows-Specific ===
  Future<bool> setVolume(int percent) async {
    final clamped = percent.clamp(0, 100);
    final r = await _terminal.run(
      '(New-Object -ComObject WScript.Shell).SendKeys([char]175)' // volume up/down hack
    );
    return r.success;
  }

  Future<bool> toggleWiFi() async {
    final r = await _terminal.run(
      'netsh interface set interface "Wi-Fi" admin=disable'
    );
    return r.success;
  }
}
