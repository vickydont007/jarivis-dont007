import 'package:flutter/services.dart';

class MacOSNativeChannel {
  static const MethodChannel _channel = MethodChannel('com.nextron/system');

  // Get system information
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final result = await _channel.invokeMethod('getSystemInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'cpu_usage': 0.0,
        'memory_usage': 0.0,
        'disk_usage': 0.0,
        'battery_level': 100.0,
        'os_name': 'macOS',
        'os_version': '',
        'hostname': '',
      };
    }
  }

  // Shutdown system
  static Future<bool> shutdown() async {
    try {
      await _channel.invokeMethod('shutdown');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Restart system
  static Future<bool> restart() async {
    try {
      await _channel.invokeMethod('restart');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sleep system
  static Future<bool> sleep() async {
    try {
      await _channel.invokeMethod('sleep');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Lock system
  static Future<bool> lock() async {
    try {
      await _channel.invokeMethod('lock');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Open application
  static Future<bool> openApp(String appName) async {
    try {
      await _channel.invokeMethod('openApp', {'appName': appName});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Open URL
  static Future<bool> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Run AppleScript
  static Future<String> runAppleScript(String script) async {
    try {
      final result = await _channel.invokeMethod('runAppleScript', {'script': script});
      return result.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }
}
