import 'dart:io';
import 'tool.dart';

class GitStatusTool extends Tool {
  GitStatusTool()
      : super(
          name: 'git_status',
          description: 'Show the working tree status of a git repository',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository (default: ~/Downloads)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    return await _runGit(['status'], workDir);
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }

  static Future<ToolResult> _runGit(List<String> args, String workDir) async {
    try {
      final result = await Process.run('git', args, workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output);
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }
}

class GitAddTool extends Tool {
  GitAddTool()
      : super(
          name: 'git_add',
          description: 'Add file contents to the git staging area',
          parameters: [
            const ToolParameter(
              name: 'files',
              description: 'Files to add (default: . for all)',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final files = params['files'] as String? ?? '.';
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    return await _runGit(['add', files], workDir);
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }

  static Future<ToolResult> _runGit(List<String> args, String workDir) async {
    try {
      final result = await Process.run('git', args, workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'Files staged');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }
}

class GitCommitTool extends Tool {
  GitCommitTool()
      : super(
          name: 'git_commit',
          description: 'Create a git commit with a message',
          parameters: [
            const ToolParameter(
              name: 'message',
              description: 'Commit message',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final message = params['message'] as String?;
    if (message == null || message.isEmpty) {
      return ToolResult.error('Commit message is required');
    }
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['commit', '-m', message], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output);
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitPushTool extends Tool {
  GitPushTool()
      : super(
          name: 'git_push',
          description: 'Push commits to a remote repository',
          parameters: [
            const ToolParameter(
              name: 'remote',
              description: 'Remote name (default: origin)',
              type: ToolParameterType.string,
              defaultValue: 'origin',
            ),
            const ToolParameter(
              name: 'branch',
              description: 'Branch name (default: main)',
              type: ToolParameterType.string,
              defaultValue: 'main',
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final remote = params['remote'] as String? ?? 'origin';
    final branch = params['branch'] as String? ?? 'main';
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['push', remote, branch], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'Pushed to $remote/$branch');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitPullTool extends Tool {
  GitPullTool()
      : super(
          name: 'git_pull',
          description: 'Pull changes from a remote repository',
          parameters: [
            const ToolParameter(
              name: 'remote',
              description: 'Remote name (default: origin)',
              type: ToolParameterType.string,
              defaultValue: 'origin',
            ),
            const ToolParameter(
              name: 'branch',
              description: 'Branch name (default: main)',
              type: ToolParameterType.string,
              defaultValue: 'main',
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final remote = params['remote'] as String? ?? 'origin';
    final branch = params['branch'] as String? ?? 'main';
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['pull', remote, branch], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'Pulled from $remote/$branch');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitDiffTool extends Tool {
  GitDiffTool()
      : super(
          name: 'git_diff',
          description: 'Show changes in the working tree',
          parameters: [
            const ToolParameter(
              name: 'file',
              description: 'Specific file to diff',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final file = params['file'] as String?;
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    final args = <String>['diff'];
    if (file != null) args.add(file);
    try {
      final result = await Process.run('git', args, workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'No changes');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitLogTool extends Tool {
  GitLogTool()
      : super(
          name: 'git_log',
          description: 'Show recent git commit history',
          parameters: [
            const ToolParameter(
              name: 'count',
              description: 'Number of commits to show (default: 10)',
              type: ToolParameterType.integer,
              defaultValue: 10,
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final count = params['count'] as int? ?? 10;
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['log', '--oneline', '-$count'], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'No commits found');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitBranchTool extends Tool {
  GitBranchTool()
      : super(
          name: 'git_branch',
          description: 'List all git branches',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['branch', '-a'], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output);
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitCheckoutTool extends Tool {
  GitCheckoutTool()
      : super(
          name: 'git_checkout',
          description: 'Switch to a different git branch',
          parameters: [
            const ToolParameter(
              name: 'branch',
              description: 'Branch name to switch to',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final branch = params['branch'] as String?;
    if (branch == null || branch.isEmpty) {
      return ToolResult.error('Branch name is required');
    }
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['checkout', branch], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'Switched to $branch');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

class GitMergeTool extends Tool {
  GitMergeTool()
      : super(
          name: 'git_merge',
          description: 'Merge a branch into the current branch',
          parameters: [
            const ToolParameter(
              name: 'branch',
              description: 'Branch name to merge',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'path',
              description: 'Path to the git repository',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final branch = params['branch'] as String?;
    if (branch == null || branch.isEmpty) {
      return ToolResult.error('Branch name is required');
    }
    final workDir = params['path'] as String? ?? _defaultWorkDir;
    try {
      final result = await Process.run('git', ['merge', branch], workingDirectory: workDir);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return ToolResult.success(output.isNotEmpty ? output : 'Merged $branch');
      }
      return ToolResult.error(error.isNotEmpty ? error : 'git exited with code ${result.exitCode}');
    } catch (e) {
      return ToolResult.error('Failed to run git: $e');
    }
  }

  String get _defaultWorkDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Downloads';
  }
}

List<Tool> getAllGitTools() {
  return [
    GitStatusTool(),
    GitAddTool(),
    GitCommitTool(),
    GitPushTool(),
    GitPullTool(),
    GitDiffTool(),
    GitLogTool(),
    GitBranchTool(),
    GitCheckoutTool(),
    GitMergeTool(),
  ];
}
