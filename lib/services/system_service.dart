import 'dart:io';
import '../core/platform.dart';
import '../core/logger.dart';
import '../models/system_info_model.dart';
import 'terminal_service.dart';

class SystemService {
  static final SystemService _instance = SystemService._internal();
  factory SystemService() => _instance;
  SystemService._internal();

  final JarvisLogger _log = JarvisLogger();
  final TerminalService _terminal = TerminalService();

  Future<SystemInfo> getInfo() async {
    final hostname = PlatformInfo.isWindows
        ? Platform.environment['COMPUTERNAME'] ?? 'unknown'
        : Platform.environment['HOSTNAME'] ?? 'unknown';
    
    final osVersion = PlatformInfo.isWindows
        ? await _getWindowsVersion()
        : await _getMacVersion();

    final cpu = await _getCpuUsage();
    final mem = await _getMemoryInfo();
    final disk = await _getDiskInfo();
    final uptime = await _getUptime();

    return SystemInfo(
      cpuUsage: cpu,
      memoryUsage: mem.$1,
      memoryTotalMB: mem.$2,
      memoryUsedMB: mem.$3,
      diskTotalGB: disk.$1,
      diskUsedGB: disk.$2,
      diskUsage: disk.$3,
      uptimeHours: uptime,
      osVersion: osVersion,
      hostname: hostname,
    );
  }

  Future<double> _getCpuUsage() async {
    final cmd = PlatformInfo.isWindows
        ? 'Get-Counter "\\Processor(_Total)\\% Processor Time" | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue'
        : 'top -l 1 -n 0 | grep "CPU usage" | awk \'{print \$3}\' | sed "s/%//"';
    final result = await _terminal.run(cmd, timeout: 5000);
    if (result.success) {
      final val = double.tryParse(result.stdout.trim());
      if (val != null) return val / 100;
    }
    return 0.5; // fallback
  }

  Future<(double, int, int)> _getMemoryInfo() async {
    if (PlatformInfo.isWindows) {
      final cmd = 'Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json';
      final result = await _terminal.run(cmd, timeout: 5000);
      if (result.success) {
        try {
          final json = result.stdout.trim();
          // Parse total and free from JSON
          final totalMatch = RegExp(r'TotalVisibleMemorySize[:\s]+(\d+)').firstMatch(json);
          final freeMatch = RegExp(r'FreePhysicalMemory[:\s]+(\d+)').firstMatch(json);
          if (totalMatch != null && freeMatch != null) {
            final totalKB = int.parse(totalMatch.group(1)!);
            final freeKB = int.parse(freeMatch.group(1)!);
            final usedKB = totalKB - freeKB;
            return (usedKB / totalKB, totalKB ~/ 1024, usedKB ~/ 1024);
          }
        } catch (_) {}
      }
    } else {
      final result = await _terminal.run('vm_stat | head -10', timeout: 5000);
      if (result.success) {
        // Parse macOS vm_stat
        try {
          final lines = result.stdout.split('\n');
          int active = 0, wired = 0, compressed = 0, free = 0, total = 0;
          for (final line in lines) {
            if (line.contains('Pages active')) active = int.parse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0');
            if (line.contains('Pages wired')) wired = int.parse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0');
            if (line.contains('Pages free')) free = int.parse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0');
            if (line.contains('Pages occupied')) compressed = int.parse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0');
            if (line.contains('mach virtual memory')) total = int.parse(RegExp(r'(\d+)').firstMatch(line)?.group(1) ?? '0');
          }
          if (total > 0) {
            final used = active + wired + compressed;
            final totalMB = total * 4096 ~/ (1024 * 1024);
            final usedMB = used * 4096 ~/ (1024 * 1024);
            return (used / total, totalMB, usedMB);
          }
        } catch (_) {}
      }
    }
    return (0.5, 8192, 4096); // fallback
  }

  Future<(int, int, double)> _getDiskInfo() async {
    if (PlatformInfo.isWindows) {
      final cmd = 'Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, Size, FreeSpace | ConvertTo-Json';
      final result = await _terminal.run(cmd, timeout: 5000);
      if (result.success) {
        try {
          final sizeMatch = RegExp(r'Size[:\s]+(\d+)').firstMatch(result.stdout);
          final freeMatch = RegExp(r'FreeSpace[:\s]+(\d+)').firstMatch(result.stdout);
          if (sizeMatch != null && freeMatch != null) {
            final total = int.parse(sizeMatch.group(1)!) ~/ (1024 * 1024 * 1024);
            final free = int.parse(freeMatch.group(1)!) ~/ (1024 * 1024 * 1024);
            final used = total - free;
            return (total, used, total > 0 ? used / total : 0.5);
          }
        } catch (_) {}
      }
    } else {
      final result = await _terminal.run('df -H / | tail -1', timeout: 5000);
      if (result.success) {
        try {
          final parts = result.stdout.trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final used = int.tryParse(parts[2].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (total > 0) return (total, used, used / total);
          }
        } catch (_) {}
      }
    }
    return (256, 128, 0.5); // fallback
  }

  Future<int> _getUptime() async {
    final cmd = PlatformInfo.isWindows
        ? '(Get-CimInstance Win32_OperatingSystem).LastBootUpTime'
        : 'uptime | awk \'{print \$3}\'';
    final result = await _terminal.run(cmd, timeout: 5000);
    if (PlatformInfo.isWindows) {
      // Parse from last boot
      final bootResult = await _terminal.run(
        '(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime | Select-Object -ExpandProperty TotalHours',
        timeout: 5000,
      );
      if (bootResult.success) {
        return int.tryParse(bootResult.stdout.trim().split('.').first) ?? 0;
      }
    } else {
      // Parse "up X days/hours"
      if (result.success) {
        // Basic parsing
        final days = RegExp(r'(\d+)\s*day').firstMatch(result.stdout);
        final hours = RegExp(r'(\d+):(\d+)').firstMatch(result.stdout);
        var totalHours = 0;
        if (days != null) totalHours += int.parse(days.group(1)!) * 24;
        if (hours != null) totalHours += int.parse(hours.group(1)!);
        return totalHours;
      }
    }
    return 0;
  }

  Future<String> _getWindowsVersion() async {
    final result = await _terminal.run(
      '(Get-CimInstance Win32_OperatingSystem).Caption',
      timeout: 5000,
    );
    return result.success ? result.stdout.trim() : 'Windows Unknown';
  }

  Future<String> _getMacVersion() async {
    final result = await _terminal.run('sw_vers -productVersion', timeout: 5000);
    return result.success ? 'macOS ${result.stdout.trim()}' : 'macOS Unknown';
  }

  Future<bool> shutdown({int delaySeconds = 0}) async {
    final cmd = PlatformInfo.isWindows
        ? 'shutdown /s /t $delaySeconds'
        : 'sudo shutdown -h +${delaySeconds ~/ 60}';
    final result = await _terminal.run(cmd);
    return result.success;
  }

  Future<bool> restart({int delaySeconds = 0}) async {
    final cmd = PlatformInfo.isWindows
        ? 'shutdown /r /t $delaySeconds'
        : 'sudo shutdown -r +${delaySeconds ~/ 60}';
    final result = await _terminal.run(cmd);
    return result.success;
  }

  Future<bool> sleep() async {
    final cmd = PlatformInfo.isWindows
        ? 'rundll32.exe powrprof.dll,SetSuspendState 0,1,0'
        : 'pmset sleepnow';
    final result = await _terminal.run(cmd);
    return result.success;
  }

  Future<bool> openApp(String appName) async {
    final cmd = PlatformInfo.isWindows
        ? 'Start-Process "$appName"'
        : 'open -a "$appName"';
    final result = await _terminal.run(cmd, timeout: 10000);
    return result.success;
  }

  Future<bool> openUrl(String url) async {
    final cmd = PlatformInfo.isWindows
        ? 'Start-Process "$url"'
        : 'open "$url"';
    final result = await _terminal.run(cmd, timeout: 10000);
    return result.success;
  }

  Future<bool> lockScreen() async {
    final cmd = PlatformInfo.isWindows
        ? 'rundll32.exe user32.dll,LockWorkStation'
        : '/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend';
    final result = await _terminal.run(cmd);
    return result.success;
  }
}
