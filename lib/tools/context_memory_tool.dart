import '../core/context_memory.dart';
import 'tool.dart';

List<Tool> getAllContextMemoryTools(ContextMemory contextMemory) {
  return [
    ContextSetTool(contextMemory),
    ContextGetTool(contextMemory),
    ContextSearchTool(contextMemory),
    ContextCategoryTool(contextMemory),
    ContextDeleteTool(contextMemory),
    ContextStatsTool(contextMemory),
  ];
}

class ContextSetTool extends Tool {
  final ContextMemory _contextMemory;

  ContextSetTool(this._contextMemory)
      : super(
          name: 'context_set',
          description: 'Store a piece of information in long-term context memory.',
          parameters: [
            const ToolParameter(
              name: 'category',
              description: 'Category for the information (e.g., "user", "project", "preference")',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'key',
              description: 'Key to identify this piece of information',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'value',
              description: 'The information to store',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'importance',
              description: 'Importance level (0-10, default 0)',
              type: ToolParameterType.integer,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _contextMemory.set(
      category: params['category'],
      key: params['key'],
      value: params['value'],
      importance: params['importance'] ?? 0,
    );
    return ToolResult.success('Stored in context memory');
  }
}

class ContextGetTool extends Tool {
  final ContextMemory _contextMemory;

  ContextGetTool(this._contextMemory)
      : super(
          name: 'context_get',
          description: 'Retrieve a specific piece of information from context memory.',
          parameters: [
            const ToolParameter(
              name: 'category',
              description: 'Category of the information',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'key',
              description: 'Key identifying the information',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final value = await _contextMemory.get(params['category'], params['key']);
    if (value == null) {
      return ToolResult.success('No entry found for this category and key', metadata: {'found': false});
    }
    return ToolResult.success(value, metadata: {'found': true});
  }
}

class ContextSearchTool extends Tool {
  final ContextMemory _contextMemory;

  ContextSearchTool(this._contextMemory)
      : super(
          name: 'context_search',
          description: 'Search context memory for relevant information.',
          parameters: [
            const ToolParameter(
              name: 'query',
              description: 'Search query to find relevant context',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'limit',
              description: 'Maximum number of results (default 10)',
              type: ToolParameterType.integer,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final results = await _contextMemory.search(
      params['query'],
      limit: params['limit'] ?? 10,
    );
    final items = results.map((e) => {
      'category': e.category,
      'key': e.key,
      'value': e.value,
      'importance': e.importance,
    }).toList();
    return ToolResult.success(items, metadata: {'count': items.length});
  }
}

class ContextCategoryTool extends Tool {
  final ContextMemory _contextMemory;

  ContextCategoryTool(this._contextMemory)
      : super(
          name: 'context_category',
          description: 'Get all entries from a specific category in context memory.',
          parameters: [
            const ToolParameter(
              name: 'category',
              description: 'Category to retrieve',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final results = await _contextMemory.getByCategory(params['category']);
    final items = results.map((e) => {
      'key': e.key,
      'value': e.value,
      'importance': e.importance,
    }).toList();
    return ToolResult.success(items, metadata: {'count': items.length});
  }
}

class ContextDeleteTool extends Tool {
  final ContextMemory _contextMemory;

  ContextDeleteTool(this._contextMemory)
      : super(
          name: 'context_delete',
          description: 'Delete a specific entry from context memory.',
          parameters: [
            const ToolParameter(
              name: 'category',
              description: 'Category of the entry to delete',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'key',
              description: 'Key of the entry to delete',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final deleted = await _contextMemory.delete(params['category'], params['key']);
    if (deleted) {
      return ToolResult.success('Deleted from context memory');
    }
    return ToolResult.error('Entry not found');
  }
}

class ContextStatsTool extends Tool {
  final ContextMemory _contextMemory;

  ContextStatsTool(this._contextMemory)
      : super(
          name: 'context_stats',
          description: 'Get statistics about the context memory system.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final stats = await _contextMemory.getStats();
    return ToolResult.success(stats);
  }
}
