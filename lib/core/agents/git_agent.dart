import 'dart:async';
import '../../tools/tool_manager.dart';

class GitOperationResult {
  final bool success;
  final String message;
  final String? output;
  final String? error;

  GitOperationResult({
    required this.success,
    required this.message,
    this.output,
    this.error,
  });
}

class GitAgent {
  final ToolManager _toolManager;

  GitAgent({required ToolManager toolManager}) : _toolManager = toolManager;

  Future<GitOperationResult> commitChanges(String message, {String? projectPath}) async {
    try {
      await _toolManager.executeTool('git_add', {'path': projectPath ?? '.'});
      final res = await _toolManager.executeTool('git_commit', {
        'message': message,
        'path': projectPath ?? '.',
      });

      if (res.success) {
        return GitOperationResult(success: true, message: 'Changes committed successfully');
      }
      return GitOperationResult(success: false, message: 'Commit failed', error: res.data?.toString());
    } catch (e) {
      return GitOperationResult(success: false, message: 'Git error occurred', error: e.toString());
    }
  }

  Future<GitOperationResult> pushToRemote(String branch, {String? projectPath}) async {
    try {
      final res = await _toolManager.executeTool('git_push', {
        'branch': branch,
        'path': projectPath ?? '.',
      });

      if (res.success) {
        return GitOperationResult(success: true, message: 'Pushed to $branch successfully');
      }
      return GitOperationResult(success: false, message: 'Push failed', error: res.data?.toString());
    } catch (e) {
      return GitOperationResult(success: false, message: 'Git error occurred', error: e.toString());
    }
  }

  Future<GitOperationResult> createBranch(String branchName, {String? projectPath}) async {
    try {
      final res = await _toolManager.executeTool('git_branch', {
        'name': branchName,
        'path': projectPath ?? '.',
      });

      if (res.success) {
        return GitOperationResult(success: true, message: 'Branch $branchName created successfully');
      }
      return GitOperationResult(success: false, message: 'Branch creation failed', error: res.data?.toString());
    } catch (e) {
      return GitOperationResult(success: false, message: 'Git error occurred', error: e.toString());
    }
  }

  Future<String> getStatus(String projectPath) async {
    final res = await _toolManager.executeTool('git_status', {'path': projectPath});
    return res.success ? (res.data?.toString() ?? 'No status') : 'Error: ${res.data}';
  }
}
