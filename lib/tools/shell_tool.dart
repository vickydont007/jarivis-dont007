import 'dart:io';
import 'tool.dart';

class ShellExecTool extends Tool {
  final List<String> _blockedCommands = [
    'rm -rf /',
    'mkfs',
    'dd if=',
    ':(){ :|:& };:',
  ];

  ShellExecTool()
      : super(
          name: 'shell_exec',
          description: 'Execute a shell command and return output',
          parameters: [
            const ToolParameter(
              name: 'command',
              description: 'Shell command to execute',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'working_directory',
              description: 'Working directory for the command',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'timeout_seconds',
              description: 'Timeout in seconds (default: 30)',
              type: ToolParameterType.integer,
              defaultValue: 30,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final command = params['command'] as String;
    final workingDir = params['working_directory'] as String?;
    final timeoutSeconds = params['timeout_seconds'] as int? ?? 30;

    if (_isBlocked(command)) {
      return ToolResult.error('This command is blocked for safety reasons');
    }

    try {
      final result = await Process.run(
        'sh',
        ['-c', command],
        workingDirectory: workingDir,
        environment: Platform.environment,
      ).timeout(Duration(seconds: timeoutSeconds));

      final output = StringBuffer();
      if (result.stdout.toString().isNotEmpty) {
        output.writeln('STDOUT:\n${result.stdout}');
      }
      if (result.stderr.toString().isNotEmpty) {
        output.writeln('STDERR:\n${result.stderr}');
      }
      output.writeln('Exit code: ${result.exitCode}');

      return ToolResult.success(
        output.toString(),
        metadata: {
          'exit_code': result.exitCode,
          'stdout': result.stdout.toString(),
          'stderr': result.stderr.toString(),
        },
      );
    } catch (e) {
      return ToolResult.error('Command execution failed: $e');
    }
  }

  bool _isBlocked(String command) {
    final lower = command.toLowerCase();
    return _blockedCommands.any((blocked) => lower.contains(blocked));
  }
}

List<Tool> getAllShellTools() {
  return [ShellExecTool()];
}
