import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class SystemInfo {
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final double batteryLevel;
  final String osName;
  final String osVersion;
  final String hostname;

  SystemInfo({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.batteryLevel,
    required this.osName,
    required this.osVersion,
    required this.hostname,
  });

  Map<String, dynamic> toMap() {
    return {
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'disk_usage': diskUsage,
      'battery_level': batteryLevel,
      'os_name': osName,
      'os_version': osVersion,
      'hostname': hostname,
    };
  }
}

class SystemService {
  static const MethodChannel _channel = MethodChannel('com.jarvis/system');
  final StreamController<SystemInfo> _systemInfoController =
      StreamController<SystemInfo>.broadcast();

  Stream<SystemInfo> get systemInfoStream => _systemInfoController.stream;

  // Get system information
  Future<SystemInfo> getSystemInfo() async {
    try {
      if (Platform.isMacOS || Platform.isWindows) {
        // Use platform channel for native access
        final result = await _channel.invokeMethod('getSystemInfo');
        return SystemInfo(
          cpuUsage: result['cpu_usage'] ?? 0.0,
          memoryUsage: result['memory_usage'] ?? 0.0,
          diskUsage: result['disk_usage'] ?? 0.0,
          batteryLevel: result['battery_level'] ?? 100.0,
          osName: result['os_name'] ?? Platform.operatingSystem,
          osVersion: result['os_version'] ?? '',
          hostname: result['hostname'] ?? '',
        );
      } else {
        // Fallback to dart:io
        return SystemInfo(
          cpuUsage: 0.0,
          memoryUsage: 0.0,
          diskUsage: 0.0,
          batteryLevel: 100.0,
          osName: Platform.operatingSystem,
          osVersion: Platform.operatingSystemVersion,
          hostname: Platform.localHostname,
        );
      }
    } catch (e) {
      return SystemInfo(
        cpuUsage: 0.0,
        memoryUsage: 0.0,
        diskUsage: 0.0,
        batteryLevel: 100.0,
        osName: Platform.operatingSystem,
        osVersion: Platform.operatingSystemVersion,
        hostname: Platform.localHostname,
      );
    }
  }

  // Start monitoring system info
  void startMonitoring({Duration interval = const Duration(seconds: 5)}) {
    Timer.periodic(interval, (timer) async {
      final info = await getSystemInfo();
      _systemInfoController.add(info);
    });
  }

  // System control commands
  Future<bool> shutdown() async {
    try {
      if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to shut down'
        ]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('shutdown', ['/s', '/t', '0']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> restart() async {
    try {
      if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to restart'
        ]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('shutdown', ['/r', '/t', '0']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sleep() async {
    try {
      if (Platform.isMacOS) {
        await Process.run('pmset', ['sleepnow']);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('rundll32.exe', ['powrprof.dll,SetSuspendState', '0,1,0']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> lock() async {
    try {
      if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to keystroke "q" using {command down, control down}'
        ]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('rundll32.exe', ['user32.dll,LockWorkStation']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> openApplication(String appName) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-a', appName]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('start', ['', appName]);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return true;
      } else if (Platform.isWindows) {
        await Process.run('start', ['', url]);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _systemInfoController.close();
  }
}
