import 'tool.dart';
import '../core/code_sandbox.dart';

class CodeExecuteTool extends Tool {
  final CodeExecutionSandbox _sandbox;

  CodeExecuteTool(this._sandbox)
      : super(
          name: 'code_execute',
          description: 'Execute code in a safe sandbox (Python or JavaScript)',
          parameters: [
            const ToolParameter(
              name: 'code',
              description: 'Code to execute',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'language',
              description: 'Programming language: python or javascript',
              type: ToolParameterType.string,
              required: true,
              enumValues: ['python', 'javascript'],
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
    final code = params['code'] as String;
    final language = params['language'] as String;
    final timeoutSeconds = params['timeout_seconds'] as int? ?? 30;

    try {
      final result = await _sandbox.execute(
        code,
        language: language,
        timeout: Duration(seconds: timeoutSeconds),
      );

      if (result.success) {
        return ToolResult.success(result.stdout, metadata: {
          'exit_code': result.exitCode,
          'duration': result.durationFormatted,
          'language': language,
        });
      } else {
        final error = StringBuffer();
        if (result.stderr.isNotEmpty) {
          error.writeln('STDERR:');
          error.writeln(result.stderr);
        }
        if (result.stdout.isNotEmpty) {
          error.writeln('STDOUT:');
          error.writeln(result.stdout);
        }
        error.writeln('Exit code: ${result.exitCode}');
        return ToolResult.error(error.toString());
      }
    } catch (e) {
      return ToolResult.error('Code execution failed: $e');
    }
  }
}

List<Tool> getAllCodeTools(CodeExecutionSandbox sandbox) {
  return [CodeExecuteTool(sandbox)];
}
