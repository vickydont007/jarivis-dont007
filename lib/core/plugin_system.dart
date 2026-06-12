import 'dart:async';

abstract class Plugin {
  final String id;
  final String name;
  final String version;
  final String description;
  bool _isEnabled = false;

  Plugin({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
  });

  bool get isEnabled => _isEnabled;

  Future<void> initialize(Map<String, dynamic> config);
  Future<void> enable();
  Future<void> disable();
  Future<void> dispose();

  Map<String, dynamic> getStatus() => {
    'id': id,
    'name': name,
    'version': version,
    'enabled': _isEnabled,
  };
}

class PluginManager {
  final Map<String, Plugin> _plugins = {};
  final StreamController<Plugin> _pluginController =
      StreamController<Plugin>.broadcast();

  Stream<Plugin> get pluginStream => _pluginController.stream;

  Future<void> registerPlugin(Plugin plugin, {Map<String, dynamic> config = const {}}) async {
    _plugins[plugin.id] = plugin;
    await plugin.initialize(config);
    _pluginController.add(plugin);
  }

  Future<void> enablePlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin != null) {
      await plugin.enable();
      _pluginController.add(plugin);
    }
  }

  Future<void> disablePlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin != null) {
      await plugin.disable();
      _pluginController.add(plugin);
    }
  }

  Future<void> unregisterPlugin(String pluginId) async {
    final plugin = _plugins.remove(pluginId);
    if (plugin != null) {
      await plugin.dispose();
      _pluginController.add(plugin);
    }
  }

  Plugin? getPlugin(String id) => _plugins[id];

  List<Plugin> getAllPlugins() => _plugins.values.toList();

  List<Plugin> getEnabledPlugins() => _plugins.values.where((p) => p.isEnabled).toList();

  List<Plugin> getDisabledPlugins() => _plugins.values.where((p) => !p.isEnabled).toList();

  Map<String, dynamic> getStats() {
    return {
      'total': _plugins.length,
      'enabled': getEnabledPlugins().length,
      'disabled': getDisabledPlugins().length,
    };
  }

  void dispose() {
    for (final plugin in _plugins.values) {
      plugin.dispose();
    }
    _plugins.clear();
    _pluginController.close();
  }
}
