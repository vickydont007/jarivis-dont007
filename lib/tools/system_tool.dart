import 'tool.dart';
import '../services/system_service.dart';

class SystemInfoTool extends Tool {
  final SystemService _service = SystemService();

  SystemInfoTool()
      : super(
          name: 'system_info',
          description: 'Get system information (CPU, memory, disk, battery, OS)',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final info = await _service.getSystemInfo();
      return ToolResult.success(info.toMap());
    } catch (e) {
      return ToolResult.error('Failed to get system info: $e');
    }
  }
}

class SystemShutdownTool extends Tool {
  final SystemService _service = SystemService();

  SystemShutdownTool()
      : super(
          name: 'system_shutdown',
          description: 'Shut down the computer',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final success = await _service.shutdown();
      if (success) {
        return ToolResult.success('System shutting down...');
      }
      return ToolResult.error('Failed to shut down system');
    } catch (e) {
      return ToolResult.error('Failed to shut down: $e');
    }
  }
}

class SystemRestartTool extends Tool {
  final SystemService _service = SystemService();

  SystemRestartTool()
      : super(
          name: 'system_restart',
          description: 'Restart the computer',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final success = await _service.restart();
      if (success) {
        return ToolResult.success('System restarting...');
      }
      return ToolResult.error('Failed to restart system');
    } catch (e) {
      return ToolResult.error('Failed to restart: $e');
    }
  }
}

class SystemSleepTool extends Tool {
  final SystemService _service = SystemService();

  SystemSleepTool()
      : super(
          name: 'system_sleep',
          description: 'Put the computer to sleep',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final success = await _service.sleep();
      if (success) {
        return ToolResult.success('System going to sleep...');
      }
      return ToolResult.error('Failed to put system to sleep');
    } catch (e) {
      return ToolResult.error('Failed to sleep: $e');
    }
  }
}

class SystemLockTool extends Tool {
  final SystemService _service = SystemService();

  SystemLockTool()
      : super(
          name: 'system_lock',
          description: 'Lock the workstation',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final success = await _service.lock();
      if (success) {
        return ToolResult.success('Workstation locked');
      }
      return ToolResult.error('Failed to lock workstation');
    } catch (e) {
      return ToolResult.error('Failed to lock: $e');
    }
  }
}

class SystemOpenAppTool extends Tool {
  final SystemService _service = SystemService();

  SystemOpenAppTool()
      : super(
          name: 'system_open_app',
          description: 'Open an application by name',
          parameters: [
            const ToolParameter(
              name: 'app_name',
              description: 'Name of the application to open',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final appName = params['app_name'] as String;
    try {
      final success = await _service.openApplication(appName);
      if (success) {
        return ToolResult.success('Opened: $appName');
      }
      return ToolResult.error('Failed to open: $appName');
    } catch (e) {
      return ToolResult.error('Failed to open app: $e');
    }
  }
}

class SystemOpenUrlTool extends Tool {
  final SystemService _service = SystemService();

  SystemOpenUrlTool()
      : super(
          name: 'system_open_url',
          description: 'Open a URL in the default browser',
          parameters: [
            const ToolParameter(
              name: 'url',
              description: 'URL to open',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final url = params['url'] as String;
    try {
      final success = await _service.openUrl(url);
      if (success) {
        return ToolResult.success('Opened URL: $url');
      }
      return ToolResult.error('Failed to open URL');
    } catch (e) {
      return ToolResult.error('Failed to open URL: $e');
    }
  }
}

List<Tool> getAllSystemTools() {
  return [
    SystemInfoTool(),
    SystemShutdownTool(),
    SystemRestartTool(),
    SystemSleepTool(),
    SystemLockTool(),
    SystemOpenAppTool(),
    SystemOpenUrlTool(),
  ];
}
