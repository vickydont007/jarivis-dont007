import 'dart:async';
import '../models/workflow.dart';
import '../services/multi_agent_orchestrator.dart';
import '../services/project_analyzer.dart';
import '../services/codebase_memory.dart';
import '../../tools/tool_manager.dart';

class ProjectBuilder {
  final MultiAgentOrchestrator _orchestrator;
  final ProjectAnalyzer _analyzer;
  final CodebaseMemory _memory;
  final ToolManager _toolManager;

  ProjectBuilder({
    required MultiAgentOrchestrator orchestrator,
    required ProjectAnalyzer analyzer,
    required CodebaseMemory memory,
    required ToolManager toolManager,
  })  : _orchestrator = orchestrator,
        _analyzer = analyzer,
        _memory = memory,
        _toolManager = toolManager;

  Future<WorkflowResult> buildProject(String projectName, String goal, String path) async {
    // 1. High-level project scaffolding
    final scaffoldGoal = 'Create project structure for $projectName: $goal. Include basic folders (lib, test, assets) and a README.';
    
    // 2. Coordination via the Multi-Agent Orchestrator
    // We define a complex goal that the orchestrator will decompose
    final fullGoal = '''
      Build a complete software project:
      Project Name: $projectName
      Goal: $goal
      Path: $path
      
      Steps:
      1. Research best practices for this type of app.
      2. Create the folder structure.
      3. Generate core architecture files (models, services, providers).
      4. Implement main features.
      5. Create basic tests.
      6. Save everything to the filesystem.
      7. Commit to git.
    ''';

    final result = await _orchestrator.executeGoal(fullGoal, context: {
      'projectName': projectName,
      'projectPath': path,
    });

    // 3. Run a final analysis to ensure it's healthy
    final analysis = await _analyzer.analyzeProject(projectName, path);
    await _memory.storeAnalysis(analysis);

    return result;
  }
}
