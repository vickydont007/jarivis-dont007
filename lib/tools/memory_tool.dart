import 'tool.dart';
import '../core/memory_system.dart';

class MemorySearchTool extends Tool {
  final MemorySystem _memory;

  MemorySearchTool(this._memory)
      : super(
          name: 'memory_search',
          description: 'Search memories by keyword (full-text search)',
          parameters: [
            const ToolParameter(
              name: 'query',
              description: 'Search query',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final query = params['query'] as String;
    try {
      final results = await _memory.searchMemory(query);
      final data = results.map((m) => {
            'id': m.id,
            'content': m.content,
            'category': m.category,
            'created_at': m.createdAt.toIso8601String(),
          }).toList();
      return ToolResult.success(data, metadata: {'count': data.length});
    } catch (e) {
      return ToolResult.error('Memory search failed: $e');
    }
  }
}

class MemoryAddTool extends Tool {
  final MemorySystem _memory;

  MemoryAddTool(this._memory)
      : super(
          name: 'memory_add',
          description: 'Add a new memory entry',
          parameters: [
            const ToolParameter(
              name: 'content',
              description: 'Memory content to store',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'category',
              description: 'Category for the memory',
              type: ToolParameterType.string,
              defaultValue: 'general',
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final content = params['content'] as String;
    final category = params['category'] as String? ?? 'general';
    try {
      final entry = MemoryEntry.create(
        content: content,
        category: category,
      );
      await _memory.addMemory(entry);
      return ToolResult.success('Memory added: ${entry.id}');
    } catch (e) {
      return ToolResult.error('Failed to add memory: $e');
    }
  }
}

class MemoryListTool extends Tool {
  final MemorySystem _memory;

  MemoryListTool(this._memory)
      : super(
          name: 'memory_list',
          description: 'List all memories or filter by category',
          parameters: [
            const ToolParameter(
              name: 'category',
              description: 'Filter by category (optional)',
              type: ToolParameterType.string,
            ),
            const ToolParameter(
              name: 'limit',
              description: 'Max number of results (default: 20)',
              type: ToolParameterType.integer,
              defaultValue: 20,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final category = params['category'] as String?;
    final limit = params['limit'] as int? ?? 20;
    try {
      List<MemoryEntry> results;
      if (category != null && category.isNotEmpty) {
        results = await _memory.getMemoriesByCategory(category);
      } else {
        results = await _memory.getAllMemories();
      }
      final data = results.take(limit).map((m) => {
            'id': m.id,
            'content': m.content,
            'category': m.category,
            'created_at': m.createdAt.toIso8601String(),
          }).toList();
      return ToolResult.success(data, metadata: {'count': data.length});
    } catch (e) {
      return ToolResult.error('Failed to list memories: $e');
    }
  }
}

class MemoryDeleteTool extends Tool {
  final MemorySystem _memory;

  MemoryDeleteTool(this._memory)
      : super(
          name: 'memory_delete',
          description: 'Delete a memory by ID',
          parameters: [
            const ToolParameter(
              name: 'id',
              description: 'Memory ID to delete',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final id = params['id'] as String;
    try {
      await _memory.deleteMemory(id);
      return ToolResult.success('Memory deleted: $id');
    } catch (e) {
      return ToolResult.error('Failed to delete memory: $e');
    }
  }
}

List<Tool> getAllMemoryTools(MemorySystem memory) {
  return [
    MemorySearchTool(memory),
    MemoryAddTool(memory),
    MemoryListTool(memory),
    MemoryDeleteTool(memory),
  ];
}
