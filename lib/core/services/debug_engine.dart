import 'dart:async';
import 'dart:io';
import '../../tools/tool_manager.dart';
import '../agents/coding_agent.dart';

class DebugSession {
  final String errorLog;
  final String projectPath;
  final List<String> attemptHistory = [];
  int retryCount = 0;

  DebugSession({required this.errorLog, required this.projectPath});
}

class DebugEngine {
  final ToolManager _toolManager;
  final CodingAgent _codingAgent;

  DebugEngine({
    required ToolManager toolManager,
    required CodingAgent codingAgent,
  })  : _toolManager = toolManager,
        _codingAgent = codingAgent;

  Future<String> diagnoseAndFix(String errorLog, String projectPath) async {
    final session = DebugSession(errorLog: errorLog, projectPath: projectPath);
    
    // 1. Parse stack trace
    final rootCause = _parseStackTrace(errorLog);
    
    // 2. Find the offending file and line
    final targetFile = _findSourceFile(rootCause, projectPath);
    if (targetFile == null) return 'Could not locate source file for error';

    // 3. Generate a fix using CodingAgent
    final fix = await _suggestFix(targetFile, rootCause, errorLog);
    
    // 4. Apply the fix
    final success = await _codingAgent.applyEdit(fix);
    
    if (success) {
      return 'Fixed error in $targetFile: ${fix.description}';
    } else {
      return 'Failed to apply fix to $targetFile';
    }
  }

  String _parseStackTrace(String log) {
    final lines = log.split('\n');
    for (final line in lines) {
      if (line.contains('.dart:') || line.contains('.py:') || line.contains('.js:')) {
        return line;
      }
    }
    return 'Unknown error source';
  }

  String? _findSourceFile(String stackLine, String projectPath) {
    final match = RegExp(r'([a-zA-Z0-9_./\\]+\.[a-zA-Z0-9]+):(\d+)').firstMatch(stackLine);
    if (match != null) {
      String file = match.group(1)!;
      if (!file.startsWith('/') && !file.startsWith('~')) {
        file = '$projectPath/$file';
      }
      return file;
    }
    return null;
  }

  Future<CodeEdit> _suggestFix(String filePath, String rootCause, String fullLog) async {
    final content = await _toolManager.executeTool('file_read', {'path': filePath});
    final fileText = content.data?.toString() ?? '';
    
    // In a real implementation, this would call the AI engine to analyze the code + error
    // Here we return a simulated edit for the architecture's sake
    return CodeEdit(
      filePath: filePath,
      startLine: 10, // Dummy
      endLine: 11,   // Dummy
      newContent: '// Fixed: $rootCause\n// Updated logic to prevent crash',
      description: 'Autonomous bug fix for $rootCause',
    );
  }
}
