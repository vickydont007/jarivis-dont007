import 'dart:async';
import 'dart:io';
import '../../tools/tool_manager.dart';

class TerminalExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final String command;

  TerminalExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    required this.command,
  });

  bool get success => exitCode == 0;
}

class TerminalAgent {
  final ToolManager _toolManager;

  TerminalAgent({required ToolManager toolManager}) : _toolManager = toolManager;

  Future<TerminalExecutionResult> runCommand(String command, {String? workingDir, Duration timeout = const Duration(minutes: 5)}) async {
    final stopwatch = Stopwatch()..start();
    try {
      // We use the shell_exec tool from ToolManager to stay consistent with sandbox rules
      final result = await _toolManager.executeTool('shell_exec', {
        'command': command,
        'workingDir': workingDir,
      }).timeout(timeout);

      stopwatch.stop();
      
      if (result.success) {
        return TerminalExecutionResult(
          exitCode: 0,
          stdout: result.data?.toString() ?? '',
          stderr: '',
          duration: stopwatch.elapsed,
          command: command,
        );
      } else {
        return TerminalExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: result.data?.toString() ?? 'Command failed',
          duration: stopwatch.elapsed,
          command: command,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return TerminalExecutionResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
        command: command,
      );
    }
  }

  Future<bool> verifyCommand(String command, {String? workingDir, String? expectedOutput}) async {
    final result = await runCommand(command, workingDir: workingDir);
    if (!result.success) return false;
    if (expectedOutput != null) {
      return result.stdout.contains(expectedOutput);
    }
    return true;
  }
}
