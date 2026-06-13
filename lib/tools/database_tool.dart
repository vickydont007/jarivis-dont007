import 'package:sqflite/sqflite.dart';
import 'tool.dart';

class _DatabaseConnections {
  static final _DatabaseConnections _instance = _DatabaseConnections._();
  factory _DatabaseConnections() => _instance;
  _DatabaseConnections._();

  final Map<String, Database> _connections = {};

  Database? get(String name) => _connections[name];
  void set(String name, Database db) => _connections[name] = db;
  Database? remove(String name) => _connections.remove(name);
  bool contains(String name) => _connections.containsKey(name);

  Future<void> closeAll() async {
    for (final db in _connections.values) {
      await db.close();
    }
    _connections.clear();
  }
}

final _connections = _DatabaseConnections();

class DbConnectTool extends Tool {
  DbConnectTool()
      : super(
          name: 'db_connect',
          description: 'Connect to a SQLite database file',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Path to the SQLite database file',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'name',
              description: 'Connection name (default: "default")',
              type: ToolParameterType.string,
              defaultValue: 'default',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    final name = params['name'] as String? ?? 'default';

    if (path == null) {
      return ToolResult.error('path is required');
    }

    try {
      final db = await openDatabase(path, readOnly: true);
      _connections.set(name, db);
      return ToolResult.success('Connected to database: $name');
    } catch (e) {
      return ToolResult.error('Failed to connect: $e');
    }
  }
}

class DbQueryTool extends Tool {
  DbQueryTool()
      : super(
          name: 'db_query',
          description: 'Execute a SQL query on a connected database',
          parameters: [
            const ToolParameter(
              name: 'sql',
              description: 'SQL query to execute',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'name',
              description: 'Database connection name (default: "default")',
              type: ToolParameterType.string,
              defaultValue: 'default',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final sql = params['sql'] as String?;
    final name = params['name'] as String? ?? 'default';

    if (sql == null) {
      return ToolResult.error('sql is required');
    }

    final db = _connections.get(name);
    if (db == null) {
      return ToolResult.error('Database "$name" not connected. Use db_connect first.');
    }

    try {
      final results = await db.rawQuery(sql);
      return ToolResult.success({
        'rows': results,
        'rowCount': results.length,
      });
    } catch (e) {
      return ToolResult.error('Query failed: $e');
    }
  }
}

class DbListTablesTool extends Tool {
  DbListTablesTool()
      : super(
          name: 'db_list_tables',
          description: 'List all tables in the connected database',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Database connection name (default: "default")',
              type: ToolParameterType.string,
              defaultValue: 'default',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String? ?? 'default';
    final db = _connections.get(name);

    if (db == null) {
      return ToolResult.error('Database "$name" not connected');
    }

    try {
      final results = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tables = results.map((r) => r['name'].toString()).toList();
      return ToolResult.success(tables);
    } catch (e) {
      return ToolResult.error('Failed to list tables: $e');
    }
  }
}

class DbDisconnectTool extends Tool {
  DbDisconnectTool()
      : super(
          name: 'db_disconnect',
          description: 'Disconnect from a database',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Database connection name (default: "default")',
              type: ToolParameterType.string,
              defaultValue: 'default',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String? ?? 'default';
    final db = _connections.remove(name);
    if (db != null) {
      await db.close();
      return ToolResult.success('Disconnected from "$name"');
    }
    return ToolResult.error('Database "$name" not found');
  }
}

class DbInfoTool extends Tool {
  DbInfoTool()
      : super(
          name: 'db_info',
          description: 'Get information about a connected database',
          parameters: [
            const ToolParameter(
              name: 'name',
              description: 'Database connection name (default: "default")',
              type: ToolParameterType.string,
              defaultValue: 'default',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String? ?? 'default';
    final db = _connections.get(name);

    if (db == null) {
      return ToolResult.error('Database "$name" not connected');
    }

    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'].toString()).toList();

      final tableInfo = <String, dynamic>{};
      for (final table in tableNames) {
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM "$table"');
        tableInfo[table] = count.first['count'];
      }

      return ToolResult.success({
        'tables': tableNames,
        'tableCounts': tableInfo,
        'path': db.path,
      });
    } catch (e) {
      return ToolResult.error('Failed to get db info: $e');
    }
  }
}

List<Tool> getAllDatabaseTools() {
  return [
    DbConnectTool(),
    DbQueryTool(),
    DbListTablesTool(),
    DbDisconnectTool(),
    DbInfoTool(),
  ];
}
