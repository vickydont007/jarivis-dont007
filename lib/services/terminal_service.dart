import 'dart:io';
import 'package:async/async.dart';
import '../core/platform.dart';
import '../core/logger.dart';

class TerminalService {
  static final TerminalService _instance = TerminalService._internal();
  factory TerminalService() => _instance;
  TerminalService._internal();

  final JarvisLogger _log = JarvisLogger();

  Future<TerminalResult> run(String command, {
    String? workdir,
    int timeout = 30000,
  }) async {
    _log.info('Running: $command', data: {'workdir': workdir, 'timeout': timeout});
    
    try {
      final shell = PlatformInfo.shellExecutable;
      final args = PlatformInfo.isWindows
          ? ['-NoProfile', '-Command', command]
          : ['-c', command];

      final process = await Process.start(shell, args,
        workingDirectory: workdir,
        runInShell: true,
      );

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      await Future.wait([
        process.stdout.transform(SystemEncoding().decoder).forEach((d) => stdout.write(d)),
        process.stderr.transform(SystemEncoding().decoder).forEach((d) => stderr.write(d)),
      ]).timeout(Duration(milliseconds: timeout));

      final exitCode = await process.exitCode;
      
      _log.info('Exit code: $exitCode');
      return TerminalResult(
        exitCode: exitCode,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
      );
    } on TimeoutException {
      _log.warning('Command timed out after ${timeout}ms');
      return TerminalResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Command timed out after ${timeout}ms',
        timedOut: true,
      );
    } catch (e) {
      _log.error('Command failed', exception: e);
      return TerminalResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
      );
    }
  }

  Future<TerminalResult> runScript(String scriptPath, {
    String? workdir,
  }) async {
    if (!await File(scriptPath).exists()) {
      return TerminalResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Script not found: $scriptPath',
      );
    }
    return run(PlatformInfo.isWindows
        ? 'powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath"'
        : 'chmod +x "$scriptPath" && "$scriptPath"',
      workdir: workdir,
    );
  }

  Future<bool> isProcessRunning(String processName) async {
    final cmd = PlatformInfo.isWindows
        ? 'Get-Process -Name "$processName" -ErrorAction SilentlyContinue'
        : 'pgrep -x "$processName" || true';
    final result = await run(cmd);
    return result.exitCode == 0 && result.stdout.trim().isNotEmpty;
  }

  Future<List<String>> listProcesses() async {
    final cmd = PlatformInfo.isWindows
        ? 'Get-Process | Select-Object -Property Name, Id, CPU | ConvertTo-Json'
        : 'ps aux | awk \'{print \$2, \$11}\'';
    final result = await run(cmd);
    if (result.exitCode != 0) return [];
    return result.stdout.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  Future<TerminalResult> runBackground(String command, {
    String? workdir,
  }) async {
    final cmd = PlatformInfo.isWindows
        ? 'Start-Process -NoNewWindow powershell -ArgumentList "-NoProfile -Command $command"'
        : 'nohup $command > /dev/null 2>&1 &';
    return run(cmd, workdir: workdir, timeout: 5000);
  }
}

class TerminalResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  TerminalResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
  });

  bool get success => exitCode == 0;
  String get output => stdout.isNotEmpty ? stdout : stderr;
}
