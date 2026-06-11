import 'dart:io';

enum AppPlatform {
  windows,
  macos,
  linux,
  unknown,
}

class PlatformInfo {
  static AppPlatform get current {
    if (Platform.isWindows) return AppPlatform.windows;
    if (Platform.isMacOS) return AppPlatform.macos;
    if (Platform.isLinux) return AppPlatform.linux;
    return AppPlatform.unknown;
  }

  static bool get isWindows => current == AppPlatform.windows;
  static bool get isMacOS => current == AppPlatform.macos;
  static bool get isDesktop => isWindows || isMacOS;

  static String get shell {
    switch (current) {
      case AppPlatform.windows:
        return 'powershell';
      case AppPlatform.macos:
        return 'zsh';
      default:
        return 'bash';
    }
  }

  static String get shellExecutable {
    switch (current) {
      case AppPlatform.windows:
        return 'powershell.exe';
      case AppPlatform.macos:
        return '/bin/zsh';
      default:
        return '/bin/bash';
    }
  }

  static String get homeDir {
    if (isWindows) {
      return Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
    }
    return Platform.environment['HOME'] ?? '/home/default';
  }

  static String get configDir {
    if (isWindows) {
      return '${Platform.environment['APPDATA'] ?? homeDir}\\jarvis_agent';
    }
    return '$homeDir/.jarvis_agent';
  }

  static String get tempDir {
    if (isWindows) {
      return Platform.environment['TEMP'] ?? '${homeDir}\\AppData\\Local\\Temp';
    }
    return '/tmp';
  }
}
