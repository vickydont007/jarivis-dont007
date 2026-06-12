import 'tool.dart';
import '../services/file_service.dart';

class FileListTool extends Tool {
  final FileService _service = FileService();

  FileListTool()
      : super(
          name: 'file_list',
          description: 'List files and directories at a given path',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Directory path to list',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    try {
      final files = await _service.listFiles(path);
      final items = files.map((f) => {
            'name': f.name,
            'path': f.path,
            'is_directory': f.isDirectory,
            'size': f.size,
            'modified': f.modifiedAt.toIso8601String(),
          }).toList();
      return ToolResult.success(items, metadata: {'count': items.length});
    } catch (e) {
      return ToolResult.error('Failed to list files: $e');
    }
  }
}

class FileReadTool extends Tool {
  final FileService _service = FileService();

  FileReadTool()
      : super(
          name: 'file_read',
          description: 'Read the contents of a file',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'File path to read',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    try {
      final content = await _service.readFile(path);
      return ToolResult.success(content);
    } catch (e) {
      return ToolResult.error('Failed to read file: $e');
    }
  }
}

class FileWriteTool extends Tool {
  final FileService _service = FileService();

  FileWriteTool()
      : super(
          name: 'file_write',
          description: 'Write content to a file (creates or overwrites)',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'File path to write to',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'content',
              description: 'Content to write',
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
      await _service.writeFile(path, content);
      return ToolResult.success('File written successfully: $path');
    } catch (e) {
      return ToolResult.error('Failed to write file: $e');
    }
  }
}

class FileDeleteTool extends Tool {
  final FileService _service = FileService();

  FileDeleteTool()
      : super(
          name: 'file_delete',
          description: 'Delete a file or directory',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Path to delete',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'recursive',
              description: 'Delete directories recursively',
              type: ToolParameterType.boolean,
              defaultValue: false,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final recursive = params['recursive'] as bool? ?? false;
    try {
      final success = await _service.delete(path, recursive: recursive);
      if (success) {
        return ToolResult.success('Deleted: $path');
      }
      return ToolResult.error('Failed to delete: $path');
    } catch (e) {
      return ToolResult.error('Failed to delete: $e');
    }
  }
}

class FileSearchTool extends Tool {
  final FileService _service = FileService();

  FileSearchTool()
      : super(
          name: 'file_search',
          description: 'Search for files by name in a directory',
          parameters: [
            const ToolParameter(
              name: 'path',
              description: 'Directory to search in',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'query',
              description: 'Search query (filename substring)',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final query = params['query'] as String;
    try {
      final files = await _service.searchFiles(path, query);
      final results = files.map((f) => {
            'name': f.name,
            'path': f.path,
            'is_directory': f.isDirectory,
            'size': f.size,
          }).toList();
      return ToolResult.success(results, metadata: {'count': results.length});
    } catch (e) {
      return ToolResult.error('Failed to search files: $e');
    }
  }
}

class FileCopyTool extends Tool {
  final FileService _service = FileService();

  FileCopyTool()
      : super(
          name: 'file_copy',
          description: 'Copy a file from source to destination',
          parameters: [
            const ToolParameter(
              name: 'source',
              description: 'Source file path',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'destination',
              description: 'Destination file path',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final source = params['source'] as String;
    final destination = params['destination'] as String;
    try {
      final success = await _service.copyFile(source, destination);
      if (success) {
        return ToolResult.success('Copied: $source -> $destination');
      }
      return ToolResult.error('Failed to copy file');
    } catch (e) {
      return ToolResult.error('Failed to copy: $e');
    }
  }
}

class FileMoveTool extends Tool {
  final FileService _service = FileService();

  FileMoveTool()
      : super(
          name: 'file_move',
          description: 'Move/rename a file',
          parameters: [
            const ToolParameter(
              name: 'source',
              description: 'Source file path',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'destination',
              description: 'Destination file path',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final source = params['source'] as String;
    final destination = params['destination'] as String;
    try {
      final success = await _service.moveFile(source, destination);
      if (success) {
        return ToolResult.success('Moved: $source -> $destination');
      }
      return ToolResult.error('Failed to move file');
    } catch (e) {
      return ToolResult.error('Failed to move: $e');
    }
  }
}

List<Tool> getAllFileTools() {
  return [
    FileListTool(),
    FileReadTool(),
    FileWriteTool(),
    FileDeleteTool(),
    FileSearchTool(),
    FileCopyTool(),
    FileMoveTool(),
  ];
}
