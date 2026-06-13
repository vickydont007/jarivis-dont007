import 'dart:io';
import 'tool.dart';

class _ClipboardHistory {
  static final _ClipboardHistory _instance = _ClipboardHistory._();
  factory _ClipboardHistory() => _instance;
  _ClipboardHistory._();

  final List<String> _history = [];
  static const int _maxHistory = 20;

  List<String> get history => List.unmodifiable(_history);

  void add(String content) {
    _history.remove(content);
    _history.insert(0, content);
    if (_history.length > _maxHistory) _history.removeLast();
  }

  void clear() => _history.clear();
}

final _clipHistory = _ClipboardHistory();

class ClipboardGetTool extends Tool {
  ClipboardGetTool()
      : super(
          name: 'clipboard_get',
          description: 'Get the current clipboard content',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final result = await Process.run('pbpaste', []);
      final content = result.stdout.toString().trim();
      if (content.isNotEmpty) {
        _clipHistory.add(content);
      }
      return ToolResult.success(content);
    } catch (e) {
      return ToolResult.error('Failed to get clipboard: $e');
    }
  }
}

class ClipboardSetTool extends Tool {
  ClipboardSetTool()
      : super(
          name: 'clipboard_set',
          description: 'Set the clipboard content',
          parameters: [
            const ToolParameter(
              name: 'content',
              description: 'Content to set in clipboard',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final content = params['content'] as String?;
    if (content == null) {
      return ToolResult.error('content is required');
    }

    try {
      final process = await Process.start('pbcopy', []);
      process.stdin.write(content);
      await process.stdin.close();

      _clipHistory.add(content);

      return ToolResult.success('Clipboard updated');
    } catch (e) {
      return ToolResult.error('Failed to set clipboard: $e');
    }
  }
}

class ClipboardHistoryTool extends Tool {
  ClipboardHistoryTool()
      : super(
          name: 'clipboard_history',
          description: 'Get clipboard history (last 20 items)',
          parameters: [
            const ToolParameter(
              name: 'count',
              description: 'Number of items to return (default: 20)',
              type: ToolParameterType.integer,
              defaultValue: 20,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final count = params['count'] as int? ?? 20;
    final items = _clipHistory.history.take(count).toList();
    return ToolResult.success({
      'history': items,
      'total': _clipHistory.history.length,
    });
  }
}

class ClipboardClearTool extends Tool {
  ClipboardClearTool()
      : super(
          name: 'clipboard_clear',
          description: 'Clear the clipboard and history',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final process = await Process.start('pbcopy', []);
      await process.stdin.close();
      _clipHistory.clear();
      return ToolResult.success('Clipboard cleared');
    } catch (e) {
      return ToolResult.error('Failed to clear clipboard: $e');
    }
  }
}

List<Tool> getAllClipboardTools() {
  return [
    ClipboardGetTool(),
    ClipboardSetTool(),
    ClipboardHistoryTool(),
    ClipboardClearTool(),
  ];
}
