import 'tool.dart';
import '../core/multi_modal.dart';
import '../core/web_automation.dart';

class ImageAnalyzeTool extends Tool {
  final MultiModalSupport _multiModal;

  ImageAnalyzeTool(this._multiModal)
      : super(
          name: 'image_analyze',
          description: 'Analyze an image to understand its content, objects, and text',
          parameters: [
            const ToolParameter(
              name: 'image_path',
              description: 'Path to the image file',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'prompt',
              description: 'Specific question about the image',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final imagePath = params['image_path'] as String;
    final prompt = params['prompt'] as String?;

    try {
      final analysis = await _multiModal.analyzeImage(imagePath, prompt: prompt);
      return ToolResult.success(analysis.toJson());
    } catch (e) {
      return ToolResult.error('Image analysis failed: $e');
    }
  }
}

class ImageAnalyzeUrlTool extends Tool {
  final MultiModalSupport _multiModal;

  ImageAnalyzeUrlTool(this._multiModal)
      : super(
          name: 'image_analyze_url',
          description: 'Analyze an image from a URL',
          parameters: [
            const ToolParameter(
              name: 'image_url',
              description: 'URL of the image',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'prompt',
              description: 'Specific question about the image',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final imageUrl = params['image_url'] as String;
    final prompt = params['prompt'] as String?;

    try {
      final analysis = await _multiModal.analyzeImageUrl(imageUrl, prompt: prompt);
      return ToolResult.success(analysis.toJson());
    } catch (e) {
      return ToolResult.error('Image analysis failed: $e');
    }
  }
}

class WebFetchPageTool extends Tool {
  final WebAutomation _automation;

  WebFetchPageTool(this._automation)
      : super(
          name: 'web_fetch_page',
          description: 'Fetch a web page and extract its content, links, and metadata',
          parameters: [
            const ToolParameter(
              name: 'url',
              description: 'URL to fetch',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final url = params['url'] as String;

    try {
      final page = await _automation.fetchPage(url);
      return ToolResult.success({
        'title': page.title,
        'content': page.content.length > 5000
            ? '${page.content.substring(0, 5000)}...'
            : page.content,
        'links_count': page.links.length,
        'images_count': page.images.length,
        'metadata': page.metadata,
      });
    } catch (e) {
      return ToolResult.error('Failed to fetch page: $e');
    }
  }
}

class WebGetLinksTool extends Tool {
  final WebAutomation _automation;

  WebGetLinksTool(this._automation)
      : super(
          name: 'web_get_links',
          description: 'Extract all links from a web page',
          parameters: [
            const ToolParameter(
              name: 'url',
              description: 'URL to extract links from',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'limit',
              description: 'Maximum number of links (default: 20)',
              type: ToolParameterType.integer,
              defaultValue: 20,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final url = params['url'] as String;
    final limit = params['limit'] as int? ?? 20;

    try {
      final links = await _automation.getLinks(url);
      return ToolResult.success(links.take(limit).toList(), metadata: {
        'total': links.length,
        'returned': limit,
      });
    } catch (e) {
      return ToolResult.error('Failed to get links: $e');
    }
  }
}

class WebOpenUrlTool extends Tool {
  final WebAutomation _automation;

  WebOpenUrlTool(this._automation)
      : super(
          name: 'web_open_url',
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
      await _automation.openInBrowser(url);
      return ToolResult.success('Opened in browser: $url');
    } catch (e) {
      return ToolResult.error('Failed to open URL: $e');
    }
  }
}

List<Tool> getAllMultiModalTools(MultiModalSupport multiModal) {
  return [
    ImageAnalyzeTool(multiModal),
    ImageAnalyzeUrlTool(multiModal),
  ];
}

List<Tool> getAllWebAutomationTools(WebAutomation automation) {
  return [
    WebFetchPageTool(automation),
    WebGetLinksTool(automation),
    WebOpenUrlTool(automation),
  ];
}
