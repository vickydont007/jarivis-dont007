import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'project_analyzer.dart';

class CodebaseMemory {
  static Database? _database;
  static const _dbName = 'nextron_codebase.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE project_metadata(
            path TEXT PRIMARY KEY,
            name TEXT,
            framework TEXT,
            languages TEXT,
            dependencies TEXT,
            last_analyzed TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE project_maps(
            path TEXT,
            folder TEXT,
            files TEXT,
            PRIMARY KEY (path, folder)
          )
        ''');
        await db.execute('''
          CREATE TABLE architecture_nodes(
            id TEXT PRIMARY KEY,
            project_path TEXT,
            node_name TEXT,
            node_type TEXT,
            description TEXT,
            dependencies TEXT,
            last_updated TEXT,
            FOREIGN KEY (project_path) REFERENCES project_metadata(path)
          )
        ''');
      },
    );
  }

  Future<void> storeAnalysis(ProjectAnalysisResult result) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('project_metadata', {
        'path': result.projectPath,
        'name': result.projectName,
        'framework': result.framework,
        'languages': jsonEncode(result.languages),
        'dependencies': jsonEncode(result.dependencies),
        'last_analyzed': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.delete('project_maps', where: 'path = ?', whereArgs: [result.projectPath]);
      for (final entry in result.projectMap.entries) {
        await txn.insert('project_maps', {
          'path': result.projectPath,
          'folder': entry.key,
          'files': jsonEncode(entry.value),
        });
      }
    });
  }

  Future<ProjectAnalysisResult?> getAnalysis(String path) async {
    final db = await database;
    final rows = await db.query('project_metadata', where: 'path = ?', whereArgs: [path]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final mapRows = await db.query('project_maps', where: 'path = ?', whereArgs: [path]);
    
    final projectMap = <String, List<String>>{};
    for (final mRow in mapRows) {
      projectMap[mRow['folder'] as String] = List<String>.from(jsonDecode(mRow['files'] as String));
    }

    return ProjectAnalysisResult(
      projectName: row['name'] as String,
      projectPath: row['path'] as String,
      framework: row['framework'] as String,
      languages: List<String>.from(jsonDecode(row['languages'] as String)),
      dependencies: List<String>.from(jsonDecode(row['dependencies'] as String)),
      projectMap: projectMap,
      keyFiles: [], // Simplified for now
      health: 'Unknown',
      score: 0,
      findings: [],
    );
  }

  Future<void> recordNode(String projectPath, String id, String name, String type, String description, List<String> deps) async {
    final db = await database;
    await db.insert('architecture_nodes', {
      'id': id,
      'project_path': projectPath,
      'node_name': name,
      'node_type': type,
      'description': description,
      'dependencies': jsonEncode(deps),
      'last_updated': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getProjectMap(String projectPath) async {
    final db = await database;
    return await db.query('project_maps', where: 'path = ?', whereArgs: [projectPath]);
  }

  Future<void> clearProject(String path) async {
    final db = await database;
    await db.delete('project_metadata', where: 'path = ?', whereArgs: [path]);
    await db.delete('project_maps', where: 'path = ?', whereArgs: [path]);
    await db.delete('architecture_nodes', where: 'project_path = ?', whereArgs: [path]);
  }
}
