import 'dart:async';
import 'dart:io';

class ExecutionResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final Duration duration;
  final String language;
  final String code;

  ExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.duration,
    required this.language,
    required this.code,
  });

  bool get success => exitCode == 0;
  String get durationFormatted => '${duration.inMilliseconds}ms';

  Map<String, dynamic> toMap() => {
    'stdout': stdout,
    'stderr': stderr,
    'exit_code': exitCode,
    'duration_ms': duration.inMilliseconds,
    'language': language,
    'success': success,
  };
}

class CodeExecutionSandbox {
  final Duration defaultTimeout;
  final int maxOutputSize;
  final List<String> _blockedPythonModules = [
    'subprocess',
    'shutil.rmtree',
    'os.system',
    'eval',
    'exec',
    '__import__',
  ];

  CodeExecutionSandbox({
    this.defaultTimeout = const Duration(seconds: 30),
    this.maxOutputSize = 50000,
  });

  Future<ExecutionResult> executePython(
    String code, {
    Duration? timeout,
    Map<String, String>? env,
  }) async {
    if (_containsBlockedCode(code, 'python')) {
      return ExecutionResult(
        stdout: '',
        stderr: 'Blocked: Code contains restricted operations',
        exitCode: 1,
        duration: Duration.zero,
        language: 'python',
        code: code,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('sandbox_');
    final scriptFile = File('${tempDir.path}/script.py');
    await scriptFile.writeAsString(code);

    final stopwatch = Stopwatch()..start();

    try {
      final result = await Process.run(
        'python3',
        [scriptFile.path],
        workingDirectory: tempDir.path,
        environment: {
          ...Platform.environment,
          ...?env,
        },
      ).timeout(timeout ?? defaultTimeout);

      stopwatch.stop();

      var stdout = result.stdout.toString();
      var stderr = result.stderr.toString();

      if (stdout.length > maxOutputSize) {
        stdout = '${stdout.substring(0, maxOutputSize)}... [truncated]';
      }
      if (stderr.length > maxOutputSize) {
        stderr = '${stderr.substring(0, maxOutputSize)}... [truncated]';
      }

      return ExecutionResult(
        stdout: stdout,
        stderr: stderr,
        exitCode: result.exitCode,
        duration: stopwatch.elapsed,
        language: 'python',
        code: code,
      );
    } on TimeoutException {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution timed out after ${timeout?.inSeconds ?? defaultTimeout.inSeconds}s',
        exitCode: -1,
        duration: stopwatch.elapsed,
        language: 'python',
        code: code,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution failed: $e',
        exitCode: -1,
        duration: stopwatch.elapsed,
        language: 'python',
        code: code,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<ExecutionResult> executeJavaScript(
    String code, {
    Duration? timeout,
    Map<String, String>? env,
  }) async {
    if (_containsBlockedCode(code, 'javascript')) {
      return ExecutionResult(
        stdout: '',
        stderr: 'Blocked: Code contains restricted operations',
        exitCode: 1,
        duration: Duration.zero,
        language: 'javascript',
        code: code,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('sandbox_');
    final scriptFile = File('${tempDir.path}/script.js');
    await scriptFile.writeAsString(code);

    final stopwatch = Stopwatch()..start();

    try {
      final result = await Process.run(
        'node',
        [scriptFile.path],
        workingDirectory: tempDir.path,
        environment: {
          ...Platform.environment,
          ...?env,
        },
      ).timeout(timeout ?? defaultTimeout);

      stopwatch.stop();

      var stdout = result.stdout.toString();
      var stderr = result.stderr.toString();

      if (stdout.length > maxOutputSize) {
        stdout = '${stdout.substring(0, maxOutputSize)}... [truncated]';
      }
      if (stderr.length > maxOutputSize) {
        stderr = '${stderr.substring(0, maxOutputSize)}... [truncated]';
      }

      return ExecutionResult(
        stdout: stdout,
        stderr: stderr,
        exitCode: result.exitCode,
        duration: stopwatch.elapsed,
        language: 'javascript',
        code: code,
      );
    } on TimeoutException {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution timed out after ${timeout?.inSeconds ?? defaultTimeout.inSeconds}s',
        exitCode: -1,
        duration: stopwatch.elapsed,
        language: 'javascript',
        code: code,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult(
        stdout: '',
        stderr: 'Execution failed: $e',
        exitCode: -1,
        duration: stopwatch.elapsed,
        language: 'javascript',
        code: code,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<ExecutionResult> execute(
    String code, {
    required String language,
    Duration? timeout,
    Map<String, String>? env,
  }) async {
    switch (language.toLowerCase()) {
      case 'python':
      case 'py':
        return executePython(code, timeout: timeout, env: env);
      case 'javascript':
      case 'js':
      case 'node':
        return executeJavaScript(code, timeout: timeout, env: env);
      default:
        return ExecutionResult(
          stdout: '',
          stderr: 'Unsupported language: $language',
          exitCode: 1,
          duration: Duration.zero,
          language: language,
          code: code,
        );
    }
  }

  bool _containsBlockedCode(String code, String language) {
    final lower = code.toLowerCase();

    if (language == 'python') {
      for (final module in _blockedPythonModules) {
        if (lower.contains(module.toLowerCase())) {
          return true;
        }
      }
      if (lower.contains('import os') || lower.contains('from os')) {
        if (lower.contains('system') || lower.contains('popen') ||
            lower.contains('remove') || lower.contains('rmdir')) {
          return true;
        }
      }
    }

    if (language == 'javascript') {
      if (lower.contains('require("child_process")') ||
          lower.contains("require('child_process')") ||
          lower.contains('process.exit') ||
          lower.contains('fs.rm') ||
          lower.contains('fs.unlink')) {
        return true;
      }
    }

    return false;
  }

  Future<bool> isPythonAvailable() async {
    try {
      final result = await Process.run('python3', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isNodeAvailable() async {
    try {
      final result = await Process.run('node', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
