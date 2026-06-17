import 'dart:async';
import 'dart:io';
import '../models/workflow.dart';
import '../../tools/tool_manager.dart';
import '../services/codebase_memory.dart';

class CodeEdit {
  final String filePath;
  final int startLine;
  final int endLine;
  final String newContent;
  final String description;

  CodeEdit({
    required this.filePath,
    required this.startLine,
    required this.endLine,
    required this.newContent,
    required this.description,
  });
}

class CodingAgent {
  final ToolManager _toolManager;
  final CodebaseMemory _codebaseMemory;

  CodingAgent({
    required ToolManager toolManager,
    required CodebaseMemory codebaseMemory,
  })  : _toolManager = toolManager,
        _codebaseMemory = codebaseMemory;

  Future<String> generateFeature(String featureDescription, String projectPath, {List<String>? dependencies}) async {
    // This would typically call the AI engine to generate multiple files
    // For now, we'll simulate the process by returning the plan and a trigger for the orchestrator
    return 'PLAN: Generate files for $featureDescription in $projectPath. Dependencies: $dependencies';
  }

  Future<bool> applyEdit(CodeEdit edit) async {
    try {
      final content = await _toolManager.executeTool('file_read', {'path': edit.filePath});
      if (!content.success) return false;

      final lines = (content.data as String).split('\n');
      if (edit.startLine < 0 || edit.endLine > lines.length) return false;

      final newLines = List<String>.from(lines);
      newLines.removeRange(edit.startLine, edit.endLine);
      newLines.insertAll(edit.startLine, edit.newContent.split('\n'));

      final finalContent = newLines.join('\n');
      final res = await _toolManager.executeTool('file_write', {
        'path': edit.filePath,
        'content': finalContent,
      });

      return res.success;
    } catch (e) {
      return false;
    }
  }

  Future<String> refactorCode(String filePath, String refactorGoal) async {
    final content = await _toolManager.executeTool('file_read', {'path': filePath});
    if (!content.success) return 'Error reading file';

    // Logic to send code + goal to AI and return a set of edits
    return 'REFACTOR_PLAN: ${refactorGoal} for $filePath';
  }

  Future<String> analyzeDependencies(String projectPath) async {
    final analysis = await _toolManager.executeTool('shell_exec', {
      'command': 'ls -R $projectPath',
    });
    return analysis.success ? analysis.data.toString() : 'Analysis failed';
  }
}
