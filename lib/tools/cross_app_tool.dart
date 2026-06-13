import '../core/cross_app_bridge.dart';
import 'tool.dart';

List<Tool> getAllCrossAppTools(CrossAppBridge bridge) {
  return [
    CheckAppInstalledTool(bridge),
    OpenAppTool(bridge),
    SendCrossAppMessageTool(bridge),
    GetAppInfoTool(bridge),
    GetInstalledAppsTool(bridge),
    SendClipboardTool(bridge),
    GetClipboardTool(bridge),
  ];
}

class CheckAppInstalledTool extends Tool {
  final CrossAppBridge _bridge;

  CheckAppInstalledTool(this._bridge)
      : super(
          name: 'check_app_installed',
          description: 'Check if an application is installed on the system.',
          parameters: [
            const ToolParameter(
              name: 'bundle_id',
              description: 'Bundle ID of the application (e.g., com.apple.Safari)',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final installed = await _bridge.isAppInstalled(params['bundle_id']);
    return ToolResult.success(
      installed ? 'App is installed' : 'App is not installed',
      metadata: {'installed': installed},
    );
  }
}

class OpenAppTool extends Tool {
  final CrossAppBridge _bridge;

  OpenAppTool(this._bridge)
      : super(
          name: 'open_app',
          description: 'Open an application by its bundle ID.',
          parameters: [
            const ToolParameter(
              name: 'bundle_id',
              description: 'Bundle ID of the application to open',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _bridge.openApp(params['bundle_id']);
    return ToolResult.success('App opened');
  }
}

class SendCrossAppMessageTool extends Tool {
  final CrossAppBridge _bridge;

  SendCrossAppMessageTool(this._bridge)
      : super(
          name: 'send_cross_app_message',
          description: 'Send a message to another application.',
          parameters: [
            const ToolParameter(
              name: 'target_app',
              description: 'Bundle ID of the target application',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'action',
              description: 'Action to perform',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'data',
              description: 'JSON string of data to send',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final message = CrossAppMessage(
      sourceApp: 'com.nextron.ai',
      targetApp: params['target_app'],
      action: params['action'],
      data: params['data'] != null ? Map<String, dynamic>.from(params['data']) : {},
      timestamp: DateTime.now(),
    );
    await _bridge.sendMessageToApp(message);
    return ToolResult.success('Message sent to ${params['target_app']}');
  }
}

class GetAppInfoTool extends Tool {
  final CrossAppBridge _bridge;

  GetAppInfoTool(this._bridge)
      : super(
          name: 'get_app_info',
          description: 'Get information about an installed application.',
          parameters: [
            const ToolParameter(
              name: 'bundle_id',
              description: 'Bundle ID of the application',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final info = await _bridge.getAppInfo(params['bundle_id']);
    if (info.isEmpty) {
      return ToolResult.error('App not found');
    }
    return ToolResult.success(info);
  }
}

class GetInstalledAppsTool extends Tool {
  final CrossAppBridge _bridge;

  GetInstalledAppsTool(this._bridge)
      : super(
          name: 'get_installed_apps',
          description: 'Get a list of all installed applications.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final apps = await _bridge.getInstalledApps();
    return ToolResult.success(
      apps,
      metadata: {'count': apps.length},
    );
  }
}

class SendClipboardTool extends Tool {
  final CrossAppBridge _bridge;

  SendClipboardTool(this._bridge)
      : super(
          name: 'send_clipboard',
          description: 'Send data to the clipboard from a specific source app.',
          parameters: [
            const ToolParameter(
              name: 'data',
              description: 'Data to copy to clipboard',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'source_app',
              description: 'Source application name',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    await _bridge.sendClipboardData(params['data'], params['source_app']);
    return ToolResult.success('Data copied to clipboard');
  }
}

class GetClipboardTool extends Tool {
  final CrossAppBridge _bridge;

  GetClipboardTool(this._bridge)
      : super(
          name: 'get_clipboard',
          description: 'Get the current clipboard content.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final data = await _bridge.getClipboardData();
    return ToolResult.success(data ?? 'Clipboard is empty');
  }
}
