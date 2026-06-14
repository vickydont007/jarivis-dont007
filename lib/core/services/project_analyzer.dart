import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProjectHealthResult {
  final String projectName;
  final String projectPath;
  final String health;
  final int score;
  final int commitCount7d;
  final int commitCount30d;
  final int todoCount;
  final bool hasReadme;
  final bool hasUncommitted;
  final int branchingCount;
  final String? lastCommitMessage;
  final DateTime? lastCommitDate;
  final List<String> findings;

  ProjectHealthResult({
    required this.projectName,
    required this.projectPath,
    required this.health,
    required this.score,
    required this.commitCount7d,
    required this.commitCount30d,
    required this.todoCount,
    required this.hasReadme,
    required this.hasUncommitted,
    required this.branchingCount,
    this.lastCommitMessage,
    this.lastCommitDate,
    this.findings = const [],
  });
}

class ProjectAnalyzer {
  Future<ProjectHealthResult> analyze(String name, String path) async {
    final findings = <String>[];
    var score = 50;

    // Expand ~ to home directory
    var resolvedPath = path;
    if (resolvedPath.startsWith('~/')) {
      resolvedPath = resolvedPath.replaceFirst('~', Platform.environment['HOME'] ?? '/Users/abc');
    }

    final dir = Directory(resolvedPath);
    if (!await dir.exists()) {
      return ProjectHealthResult(
        projectName: name,
        projectPath: path,
        health: 'Unknown',
        score: 0,
        commitCount7d: 0,
        commitCount30d: 0,
        todoCount: 0,
        hasReadme: false,
        hasUncommitted: false,
        branchingCount: 0,
        findings: ['Path does not exist: $path'],
      );
    }

    // Check if git repo
    final isGit = await _runGit(resolvedPath, 'rev-parse --git-dir').then((r) => r.exitCode == 0);

    if (!isGit) {
      findings.add('Not a git repository');
      score = 30;

      // Count TODO comments anyway
      final todoCount = await _countTodos(resolvedPath);
      final hasReadme = await _hasReadme(resolvedPath);

      return ProjectHealthResult(
        projectName: name,
        projectPath: path,
        health: 'Inactive',
        score: score,
        commitCount7d: 0,
        commitCount30d: 0,
        todoCount: todoCount,
        hasReadme: hasReadme,
        hasUncommitted: false,
        branchingCount: 0,
        findings: findings,
      );
    }

    // Git analysis
    final commits7d = await _runGit(resolvedPath,
        'log --oneline --since="7 days ago" --format="%h %s"');
    final String stdout7d = commits7d.stdout.toString();
    final commitCount7d = stdout7d.trim().isEmpty
        ? 0
        : stdout7d.trim().split('\n').length;

    final commits30d = await _runGit(resolvedPath,
        'log --oneline --since="30 days ago" --format="%h %s"');
    final String stdout30d = commits30d.stdout.toString();
    final commitCount30d = stdout30d.trim().isEmpty
        ? 0
        : stdout30d.trim().split('\n').length;

    final lastCommit = await _runGit(resolvedPath,
        'log -1 --format="%s|%ai"');
    final String lastStdout = lastCommit.stdout.toString();
    String? lastCommitMessage;
    DateTime? lastCommitDate;
    if (lastCommit.exitCode == 0 && lastStdout.trim().isNotEmpty) {
      final parts = lastStdout.trim().split('|');
      if (parts.length >= 2) {
        lastCommitMessage = parts[0];
        lastCommitDate = DateTime.tryParse(parts[1]);
      }
    }

    final status = await _runGit(resolvedPath, 'status --porcelain');
    final String statusStdout = status.stdout.toString();
    final hasUncommitted = statusStdout.trim().isNotEmpty;

    final branches = await _runGit(resolvedPath, 'branch --list');
    final String branchStdout = branches.stdout.toString();
    final branchingCount = branchStdout.trim().isEmpty
        ? 0
        : branchStdout.trim().split('\n').length;

    final todoCount = await _countTodos(resolvedPath);
    final hasReadme = await _hasReadme(resolvedPath);

    // Calculate score
    score = 0;
    score += (commitCount7d * 10).clamp(0, 40).toInt();
    score += hasReadme ? 15 : 0;
    score += hasUncommitted ? 0 : 10;
    score += branchingCount > 1 ? 5 : 0;
    score += todoCount > 0 ? 10 : 5;
    score -= (todoCount > 20 ? 10 : 0);
    score = score.clamp(0, 100);

    // Health classification
    String health;
    if (score >= 80) {
      health = 'Healthy';
    } else if (score >= 60) {
      health = 'Active';
    } else if (score >= 30) {
      health = 'Needs Attention';
    } else {
      health = 'Stalled';
    }

    // Generate findings
    if (hasUncommitted) findings.add('Has uncommitted changes');
    if (commitCount7d == 0 && commitCount30d > 0) findings.add('No commits in 7 days');
    if (commitCount30d == 0) findings.add('No commits in 30 days');
    if (todoCount > 10) findings.add('$todoCount TODO/FIXME comments');
    if (!hasReadme) findings.add('Missing README');
    if (branches.stdout.trim().split('\n').length > 5) {
      findings.add('${branchingCount} branches - may need cleanup');
    }

    return ProjectHealthResult(
      projectName: name,
      projectPath: path,
      health: health,
      score: score,
      commitCount7d: commitCount7d,
      commitCount30d: commitCount30d,
      todoCount: todoCount,
      hasReadme: hasReadme,
      hasUncommitted: hasUncommitted,
      branchingCount: branchingCount,
      lastCommitMessage: lastCommitMessage,
      lastCommitDate: lastCommitDate,
      findings: findings,
    );
  }

  Future<ProcessResult> _runGit(String path, String args) async {
    try {
      return await Process.run('git', args.split(' '),
          workingDirectory: path,
          runInShell: true,
      );
    } catch (e) {
      return ProcessResult(0, -1, '', '');
    }
  }

  Future<int> _countTodos(String path) async {
    try {
      final result = await Process.run(
        'grep',
        ['-r', '-l', '--include=*.dart', '--include=*.ts', '--include=*.js',
         '--include=*.py', '--include=*.java', '--include=*.swift',
         '--include=*.rs', '--include=*.go', '--include=*.rb',
         '--include=*.kt', '--include=*.tsx', '--include=*.jsx',
         '-E', '(TODO|FIXME|HACK|XXX)', path],
        runInShell: true,
      );
      return result.stdout.toString().trim().isEmpty
          ? 0
          : result.stdout.toString().trim().split('\n').length;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> _hasReadme(String path) async {
    try {
      final files = await Directory(path).list().firstWhere(
        (f) => f is File && f.path.split('/').last.toUpperCase().startsWith('README'),
        orElse: () => throw Exception(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
