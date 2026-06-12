import 'tool.dart';

class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(List<Tool> tools) {
    for (final tool in tools) {
      _tools[tool.name] = tool;
    }
  }

  Tool? getTool(String name) {
    return _tools[name];
  }

  List<Tool> get tools => _tools.values.toList();

  List<String> get toolNames => _tools.keys.toList();

  bool hasTool(String name) => _tools.containsKey(name);

  List<Map<String, dynamic>> getToolDefinitions() {
    return _tools.values.map((t) => t.toJson()).toList();
  }

  List<Tool> searchTools(String query) {
    final lower = query.toLowerCase();
    return _tools.values.where((tool) {
      return tool.name.toLowerCase().contains(lower) ||
          tool.description.toLowerCase().contains(lower);
    }).toList();
  }

  List<Tool> getToolsByCategory(String category) {
    return _tools.values.where((tool) {
      return tool.name.startsWith(category);
    }).toList();
  }

  void remove(String name) {
    _tools.remove(name);
  }

  void clear() {
    _tools.clear();
  }

  int get count => _tools.length;
}
