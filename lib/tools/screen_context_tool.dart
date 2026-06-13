import '../core/screen_context.dart';
import 'tool.dart';

List<Tool> getAllScreenContextTools(ScreenContext screenContext) {
  return [
    ScreenCaptureTool(screenContext),
    ScreenCaptureOCRTool(screenContext),
    AccessibilityInfoTool(screenContext),
    ActiveAppTool(screenContext),
    RunningAppsTool(screenContext),
  ];
}

class ScreenCaptureTool extends Tool {
  final ScreenContext _screenContext;

  ScreenCaptureTool(this._screenContext)
      : super(
          name: 'screen_capture',
          description: 'Capture a screenshot of the current screen.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final result = await _screenContext.captureScreen();
    if (result.success) {
      return ToolResult.success(
        'Screenshot captured',
        metadata: {'path': result.screenshotPath},
      );
    }
    return ToolResult.error(result.error ?? 'Failed to capture screen');
  }
}

class ScreenCaptureOCRTool extends Tool {
  final ScreenContext _screenContext;

  ScreenCaptureOCRTool(this._screenContext)
      : super(
          name: 'screen_capture_ocr',
          description: 'Capture a screenshot and extract text using OCR.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final result = await _screenContext.captureScreenWithOCR();
    if (result.success) {
      return ToolResult.success(
        result.ocrText ?? 'No text found',
        metadata: {
          'path': result.screenshotPath,
          'hasText': result.ocrText != null && result.ocrText!.isNotEmpty,
        },
      );
    }
    return ToolResult.error(result.error ?? 'Failed to capture screen with OCR');
  }
}

class AccessibilityInfoTool extends Tool {
  final ScreenContext _screenContext;

  AccessibilityInfoTool(this._screenContext)
      : super(
          name: 'accessibility_info',
          description: 'Get information about the currently focused UI element.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final result = await _screenContext.getAccessibilityInfo();
    if (result.success) {
      return ToolResult.success(
        'Focused element: ${result.focusedElement}',
        metadata: {
          'focusedElement': result.focusedElement,
          'app': result.uiTree,
        },
      );
    }
    return ToolResult.error(result.error ?? 'Failed to get accessibility info');
  }
}

class ActiveAppTool extends Tool {
  final ScreenContext _screenContext;

  ActiveAppTool(this._screenContext)
      : super(
          name: 'active_app',
          description: 'Get the currently active (frontmost) application.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final result = await _screenContext.getActiveApplication();
    if (result != null) {
      return ToolResult.success(result);
    }
    return ToolResult.error('No active application found');
  }
}

class RunningAppsTool extends Tool {
  final ScreenContext _screenContext;

  RunningAppsTool(this._screenContext)
      : super(
          name: 'running_apps',
          description: 'Get a list of all running applications.',
          parameters: [],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final apps = await _screenContext.getRunningApplications();
    return ToolResult.success(
      apps,
      metadata: {'count': apps.length},
    );
  }
}
