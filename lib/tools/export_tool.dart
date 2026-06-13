import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'tool.dart';

class ExportChatMdTool extends Tool {
  ExportChatMdTool()
      : super(
          name: 'export_chat_md',
          description: 'Export chat history as a Markdown file',
          parameters: [
            const ToolParameter(
              name: 'messages',
              description: 'List of messages to export [{role, content, timestamp}]',
              type: ToolParameterType.array,
              required: true,
            ),
            const ToolParameter(
              name: 'filename',
              description: 'Output filename (default: auto-generated)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final messages = params['messages'] as List?;
    final filename = params['filename'] as String? ?? 'nextron_chat_${DateTime.now().millisecondsSinceEpoch}.md';

    if (messages == null || messages.isEmpty) {
      return ToolResult.error('messages list is required');
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('# Nextron Chat Export');
      buffer.writeln();
      buffer.writeln('Exported on: ${DateTime.now().toLocal()}');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      for (final msg in messages) {
        final role = msg['role'] as String? ?? 'unknown';
        final content = msg['content'] as String? ?? '';
        final time = msg['timestamp'] as String? ?? '';

        final label = role == 'user' ? '**You**' : '**Nextron**';
        buffer.writeln('$label $time');
        buffer.writeln();
        buffer.writeln(content);
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }

      final home = Platform.environment['HOME'] ?? '';
      final exportDir = p.join(home, 'Downloads');
      final file = File(p.join(exportDir, filename));
      await file.writeAsString(buffer.toString());

      return ToolResult.success('Chat exported to: ${file.path}');
    } catch (e) {
      return ToolResult.error('Failed to export: $e');
    }
  }
}

class ExportChatJsonTool extends Tool {
  ExportChatJsonTool()
      : super(
          name: 'export_chat_json',
          description: 'Export chat history as a JSON file',
          parameters: [
            const ToolParameter(
              name: 'messages',
              description: 'List of messages to export [{role, content, timestamp}]',
              type: ToolParameterType.array,
              required: true,
            ),
            const ToolParameter(
              name: 'filename',
              description: 'Output filename (default: auto-generated)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final messages = params['messages'] as List?;
    final filename = params['filename'] as String? ?? 'nextron_chat_${DateTime.now().millisecondsSinceEpoch}.json';

    if (messages == null || messages.isEmpty) {
      return ToolResult.error('messages list is required');
    }

    try {
      final exportData = {
        'exported_at': DateTime.now().toIso8601String(),
        'app': 'Nextron AI',
        'version': '1.0.0',
        'messages': messages,
      };

      final home = Platform.environment['HOME'] ?? '';
      final exportDir = p.join(home, 'Downloads');
      final file = File(p.join(exportDir, filename));
      await file.writeAsString(jsonEncode(exportData));

      return ToolResult.success('Chat exported to: ${file.path}');
    } catch (e) {
      return ToolResult.error('Failed to export: $e');
    }
  }
}

List<Tool> getAllExportTools() {
  return [
    ExportChatMdTool(),
    ExportChatJsonTool(),
  ];
}
