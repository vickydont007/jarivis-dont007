import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProjectAnalysisResult {
  final String projectName;
  final String projectPath;
  final String framework;
  final List<String> languages;
  final List<String> dependencies;
  final Map<String, List<String>> projectMap; // folder -> files
  final List<String> keyFiles;
  final String health;
  final int score;
  final List<String> findings;

  ProjectAnalysisResult({
    required this.projectName,
    required this.projectPath,
    required this.framework,
    required this.languages,
    required this.dependencies,
    required this.projectMap,
    required this.keyFiles,
    required this.health,
    required this.score,
    required this.findings,
  });

  Map<String, dynamic> toMap() => {
    'projectName': projectName,
    'projectPath': projectPath,
    'framework': framework,
    'languages': languages,
    'dependencies': dependencies,
    'projectMap': projectMap,
    'keyFiles': keyFiles,
    'health': health,
    'score': score,
    'findings': findings,
  };
}

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
  Future<ProjectAnalysisResult> analyzeProject(String name, String path) async {
    var resolvedPath = path;
    if (resolvedPath.startsWith('~/')) {
      resolvedPath = resolvedPath.replaceFirst('~', Platform.environment['HOME'] ?? '/Users/abc');
    }

    final dir = Directory(resolvedPath);
    if (!await dir.exists()) {
      throw Exception('Path does not exist: $path');
    }

    final projectMap = <String, List<String>>{};
    final languages = <String>{};
    final dependencies = <String>{};
    final keyFiles = <String>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final filePath = entity.path;
        final fileName = filePath.split('/').last;
        final folder = filePath.substring(0, filePath.lastIndexOf('/'));
        
        projectMap.putIfAbsent(folder, () => []).add(fileName);
        
        // Language detection
        if (fileName.endsWith('.dart')) languages.add('Dart');
        else if (fileName.endsWith('.py')) languages.add('Python');
        else if (fileName.endsWith('.js') || fileName.endsWith('.ts')) languages.add('TypeScript/JavaScript');
        else if (fileName.endsWith('.rs')) languages.add('Rust');
        else if (fileName.endsWith('.go')) languages.add('Go');
        else if (fileName.endsWith('.java') || fileName.endsWith('.kt')) languages.add('Java/Kotlin');
        else if (fileName.endsWith('.swift')) languages.add('Swift');
        
        // Key files
        if (fileName == 'pubspec.yaml' || fileName == 'package.json' || fileName == 'requirements.txt' || fileName == 'Cargo.toml' || fileName == 'README.md') {
          keyFiles.add(fileName);
        }
      }
    }

    // Framework and dependency detection
    String framework = 'Unknown';
    for (final file in keyFiles) {
      final fullPath = '$resolvedPath/$file';
      final content = await File(fullPath).readAsString();
      
      if (file == 'pubspec.yaml') {
        if (content.contains('flutter:')) framework = 'Flutter';
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('  ')) {
            final parts = line.trim().split(':');
            if (parts.length >= 1) dependencies.add(parts[0].trim());
          }
        }
      } else if (file == 'package.json') {
        try {
          final json = jsonDecode(content);
          final deps = Map<String, dynamic>.from(json['dependencies'] ?? {});
          final devDeps = Map<String, dynamic>.from(json['devDependencies'] ?? {});
          dependencies.addAll(deps.keys);
          dependencies.addAll(devDeps.keys);
          
          if (deps.containsKey('react') || deps.containsKey('next')) framework = 'React/Next.js';
        } catch (_) {}
      } else if (file == 'requirements.txt') {
        framework = 'Python Project';
        for (final line in content.split('\n')) {
          if (line.trim().isNotEmpty && !line.trim().startsWith('#')) {
            dependencies.add(line.trim().split('==')[0]);
          }
        }
      }
    }

    final healthResult = await analyzeHealth(name, path);

    return ProjectAnalysisResult(
      projectName: name,
      projectPath: path,
      framework: framework,
      languages: languages.toList(),
      dependencies: dependencies.toList(),
      projectMap: projectMap,
      keyFiles: keyFiles,
      health: healthResult.health,
      score: healthResult.score,
      findings: healthResult.findings,
    );
  }

  Future<ProjectHealthResult> analyzeHealth(String name, String path) async {
    final findings = <String>[];
    var score = 50;

    var resolvedPath = path;
    if (resolvedPath.startsWith('~/')) {
      resolvedPath = resolvedPath.replaceFirst('~', Platform.environment['HOME'] ?? '/Users/abc');
    }

    final dir = Directory(resolvedPath);
    if (!await dir.exists()) {
      return ProjectHealthResult(
        projectName: name, projectPath: path, health: 'Unknown', score: 0,
        commitCount7d: 0, commitCount30d: 0, todoCount: 0, hasReadme: false,
        hasUncommitted: false, branchingCount: 0, findings: ['Path does not exist'],
      );
    }

    final isGit = await _runGit(resolvedPath, 'rev-parse --git-dir').then((r) => r.exitCode == 0);

    if (!isGit) {
      findings.add('Not a git repository');
      score = 30;
      final todoCount = await _countTodos(resolvedPath);
      final hasReadme = await _hasReadme(resolvedPath);
      return ProjectHealthResult(
        projectName: name, projectPath: path, health: 'Inactive', score: score,
        commitCount7d: 0, commitCount30d: 0, todoCount: todoCount, hasReadme: hasReadme,
        hasUncommitted: false, branchingCount: 0, findings: findings,
      );
    }

    final commits7d = await _runGit(resolvedPath, 'log --oneline --since="7 days ago" --format="%h %s"');
    final commitCount7d = commits7d.stdout.toString().trim().isEmpty ? 0 : commits7d.stdout.toString().trim().split('\n').length;

    final commits30d = await _runGit(resolvedPath, 'log --oneline --since="30 days ago" --format="%h %s"');
    final commitCount30d = commits30d.stdout.toString().trim().isEmpty ? 0 : commits30d.stdout.toString().trim().split('\n').length;

    final lastCommit = await _runGit(resolvedPath, 'log -1 --format="%s|%ai"');
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
    final hasUncommitted = status.stdout.toString().trim().isNotEmpty;

    final branches = await _runGit(resolvedPath, 'branch --list');
    final branchingCount = branches.stdout.toString().trim().isEmpty ? 0 : branches.stdout.toString().trim().split('\n').length;

    final todoCount = await _countTodos(resolvedPath);
    final hasReadme = await _hasReadme(resolvedPath);

    score = 0;
    score += (commitCount7d * 10).clamp(0, 40).toInt();
    score += hasReadme ? 15 : 0;
    score += hasUncommitted ? 0 : 10;
    score += branchingCount > 1 ? 5 : 0;
    score += todoCount > 0 ? 10 : 5;
    score -= (todoCount > 20 ? 10 : 0);
    score = score.clamp(0, 100);

    String health;
    if (score >= 80) health = 'Healthy';
    else if (score >= 60) health = 'Active';
    else if (score >= 30) health = 'Needs Attention';
    else health = 'Stalled';

    if (hasUncommitted) findings.add('Has uncommitted changes');
    if (commitCount7d == 0 && commitCount30d > 0) findings.add('No commits in 7 days');
    if (commitCount30d == 0) findings.add('No commits in 30 days');
    if (todoCount > 10) findings.add('$todoCount TODO/FIXME comments');
    if (!hasReadme) findings.add('Missing README');
    if (branchingCount > 5) findings.add('$branchingCount branches - may need cleanup');

    return ProjectHealthResult(
      projectName: name, projectPath: path, health: health, score: score,
      commitCount7d: commitCount7d, commitCount30d: commitCount30d, todoCount: todoCount,
      hasReadme: hasReadme, hasUncommitted: hasUncommitted, branchingCount: branchingCount,
      lastCommitMessage: lastCommitMessage, lastCommitDate: lastCommitDate, findings: findings,
    );
  }

  Future<ProcessResult> _runGit(String path, String args) async {
    try {
      return await Process.run('git', args.split(' '), workingDirectory: path, runInShell: true);
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
      return result.stdout.toString().trim().isEmpty ? 0 : result.stdout.toString().trim().split('\n').length;
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
