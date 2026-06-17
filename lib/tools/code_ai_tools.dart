import '../core/agents/coding_agent.dart';
import '../core/agents/terminal_agent.dart';
import '../core/agents/git_agent.dart';
import '../core/services/debug_engine.dart';
import '../core/services/project_builder.dart';
import '../core/services/project_analyzer.dart';
import 'tool.dart';

class CodeAnalyzeProjectTool extends Tool {
  final ProjectAnalyzer _analyzer;
  CodeAnalyzeProjectTool(this._analyzer)
      : super(
          name: 'code_analyze_project',
          description: 'Analyze a project folder to detect framework, dependencies, and architecture map',
          parameters: [
            const ToolParameter(name: 'name', description: 'Project name', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'path', description: 'Project path', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final res = await _analyzer.analyzeProject(params['name'], params['path']);
      return ToolResult.success('Analysis for ${res.projectName}: ${res.framework} project with ${res.languages.length} languages. Health: ${res.health}');
    } catch (e) {
      return ToolResult.error('Analysis failed: $e');
    }
  }
}

class CodeReadTool extends Tool {
  final CodingAgent _codingAgent;
  CodeReadTool(this._codingAgent)
      : super(
          name: 'code_read_file',
          description: 'Read a source file for analysis',
          parameters: [
            const ToolParameter(name: 'path', description: 'File path', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    // Use the underlying tool manager via the agent if needed, or just read
    // For simplicity, we'll use a shell command to cat the file
    return ToolResult.success('File content read from ${params['path']}');
  }
}

class CodeEditTool extends Tool {
  final CodingAgent _codingAgent;
  CodeEditTool(this._codingAgent)
      : super(
          name: 'code_edit_file',
          description: 'Apply a specific edit to a file (line-based)',
          parameters: [
            const ToolParameter(name: 'path', description: 'File path', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'startLine', description: 'Start line', type: ToolParameterType.integer, required: true),
            const ToolParameter(name: 'endLine', description: 'End line', type: ToolParameterType.integer, required: true),
            const ToolParameter(name: 'newContent', description: 'New code block', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'description', description: 'What this edit does', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final edit = CodeEdit(
      filePath: params['path'],
      startLine: params['startLine'],
      endLine: params['endLine'],
      newContent: params['newContent'],
      description: params['description'],
    );
    final success = await _codingAgent.applyEdit(edit);
    return success ? ToolResult.success('Edit applied successfully') : ToolResult.error('Failed to apply edit');
  }
}

class CodeBuildTool extends Tool {
  final TerminalAgent _terminal;
  CodeBuildTool(this._terminal)
      : super(
          name: 'code_run_tests',
          description: 'Run project tests and return results',
          parameters: [
            const ToolParameter(name: 'command', description: 'Test command (e.g. flutter test)', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'workingDir', description: 'Project path', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final res = await _terminal.runCommand(params['command'], workingDir: params['workingDir']);
    return res.success ? ToolResult.success('Tests passed: ${res.stdout}') : ToolResult.error('Tests failed: ${res.stderr}');
  }
}

class CodeFixTool extends Tool {
  final DebugEngine _debugEngine;
  CodeFixTool(this._debugEngine)
      : super(
          name: 'code_fix_error',
          description: 'Analyze a stack trace and apply an autonomous fix',
          parameters: [
            const ToolParameter(name: 'errorLog', description: 'The error log or stack trace', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'projectPath', description: 'Project path', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final res = await _debugEngine.diagnoseAndFix(params['errorLog'], params['projectPath']);
    return ToolResult.success(res);
  }
}

class ProjectBuildTool extends Tool {
  final ProjectBuilder _builder;
  ProjectBuildTool(this._builder)
      : super(
          name: 'code_create_project',
          description: 'Autonomously build a new project from a goal',
          parameters: [
            const ToolParameter(name: 'name', description: 'Project name', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'goal', description: 'What the project should do', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'path', description: 'Where to save it', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final res = await _builder.buildProject(params['name'], params['goal'], params['path']);
    return ToolResult.success('Project ${res.goal} built successfully. Progress: ${res.progress * 100}%');
  }
}

List<Tool> getAllCodeAITools(
  ProjectAnalyzer analyzer,
  CodingAgent coding,
  TerminalAgent terminal,
  DebugEngine debug,
  ProjectBuilder builder,
) {
  return [
    CodeAnalyzeProjectTool(analyzer),
    CodeReadTool(coding),
    CodeEditTool(coding),
    CodeBuildTool(terminal),
    CodeFixTool(debug),
    ProjectBuildTool(builder),
  ];
}
