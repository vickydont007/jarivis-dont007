import 'tool.dart';
import '../services/file_manager_service.dart';

class FileRenameTool extends Tool {
  final FileManagerService _service = FileManagerService();

  FileRenameTool()
      : super(
          name: 'file_rename',
          description: 'Rename a file or folder',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Current file path',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'new_name',
              description: 'New filename (not full path, just the name)',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final newName = params['new_name'] as String;
    try {
      final success = await _service.renameFile(path, newName);
      if (success) {
        return ToolResult.success('Renamed to: $newName');
      }
      return ToolResult.error('Failed to rename file');
    } catch (e) {
      return ToolResult.error('Rename failed: $e');
    }
  }
}

class FileAppendTool extends Tool {
  final FileManagerService _service = FileManagerService();

  FileAppendTool()
      : super(
          name: 'file_append',
          description: 'Append content to the end of a file',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'File path to append to',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'content',
              description: 'Content to append',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final content = params['content'] as String;
    try {
      await _service.appendFile(path, content);
      return ToolResult.success('Content appended to: $path');
    } catch (e) {
      return ToolResult.error('Append failed: $e');
    }
  }
}

class FileCreateFolderTool extends Tool {
  final FileManagerService _service = FileManagerService();

  FileCreateFolderTool()
      : super(
          name: 'file_create_folder',
          description: 'Create a new folder/directory',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Folder path to create',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    try {
      await _service.createFolder(path);
      return ToolResult.success('Folder created: $path');
    } catch (e) {
      return ToolResult.error('Failed to create folder: $e');
    }
  }
}

class FileGetInfoTool extends Tool {
  final FileManagerService _service = FileManagerService();

  FileGetInfoTool()
      : super(
          name: 'file_get_info',
          description: 'Get detailed metadata about a file or folder',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'File or folder path',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    try {
      final info = await _service.getFileInfo(path);
      return ToolResult.success(info);
    } catch (e) {
      return ToolResult.error('Failed to get file info: $e');
    }
  }
}

class FileSearchContentTool extends Tool {
  final FileManagerService _service = FileManagerService();

  FileSearchContentTool()
      : super(
          name: 'file_search_content',
          description: 'Search for files containing specific text content',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Directory to search in',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'query',
              description: 'Text content to search for',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'max_results',
              description: 'Maximum results to return',
              type: ToolParameterType.integer,
              defaultValue: 20,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final query = params['query'] as String;
    final maxResults = params['max_results'] as int? ?? 20;
    try {
      final files =
          await _service.searchByContent(path, query, maxResults: maxResults);
      final results = files
          .map((f) => {
                'name': f.name,
                'path': f.path,
                'size': f.size,
                'modified': f.modifiedAt.toIso8601String(),
              })
          .toList();
      return ToolResult.success(results, metadata: {'count': results.length});
    } catch (e) {
      return ToolResult.error('Content search failed: $e');
    }
  }
}

class FileSearchRecursiveTool extends Tool {
  final FileManagerService _service = FileManagerService();

  FileSearchRecursiveTool()
      : super(
          name: 'file_search_recursive',
          description: 'Recursively search for files by name in all subdirectories',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Root directory to search from',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'query',
              description: 'Filename pattern to search for',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'extension',
              description: 'Filter by file extension (e.g., ".pdf", ".md")',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final query = params['query'] as String;
    final extension = params['extension'] as String?;
    try {
      final files = await _service.searchFiles(
        path,
        query,
        recursive: true,
        extension: extension,
      );
      final results = files
          .map((f) => {
                'name': f.name,
                'path': f.path,
                'is_directory': f.isDirectory,
                'size': f.size,
              })
          .toList();
      return ToolResult.success(results, metadata: {'count': results.length});
    } catch (e) {
      return ToolResult.error('Recursive search failed: $e');
    }
  }
}

List<Tool> getAllFileManagerTools() {
  return [
    FileRenameTool(),
    FileAppendTool(),
    FileCreateFolderTool(),
    FileGetInfoTool(),
    FileSearchContentTool(),
    FileSearchRecursiveTool(),
  ];
}
