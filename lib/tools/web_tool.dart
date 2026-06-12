import 'package:dio/dio.dart';
import 'tool.dart';

class WebFetchTool extends Tool {
  final Dio _dio = Dio();

  WebFetchTool()
      : super(
          name: 'web_fetch',
          description: 'Fetch content from a URL',
          parameters: [
            const ToolParameter(
              name: 'url',
              description: 'URL to fetch',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'max_length',
              description: 'Maximum content length to return (default: 5000)',
              type: ToolParameterType.integer,
              defaultValue: 5000,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final url = params['url'] as String;
    final maxLength = params['max_length'] as int? ?? 5000;

    try {
      final response = await _dio.get(
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Nextron/1.0)',
          },
        ),
        url,
      );

      var content = response.data.toString();
      if (content.length > maxLength) {
        content = '${content.substring(0, maxLength)}... [truncated]';
      }

      return ToolResult.success(content, metadata: {
        'status_code': response.statusCode,
        'content_type': response.headers.value('content-type'),
        'length': content.length,
      });
    } catch (e) {
      return ToolResult.error('Failed to fetch URL: $e');
    }
  }
}

class WebSearchTool extends Tool {
  final Dio _dio = Dio();

  WebSearchTool()
      : super(
          name: 'web_search',
          description: 'Search the web using DuckDuckGo',
          parameters: [
            const ToolParameter(
              name: 'query',
              description: 'Search query',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'num_results',
              description: 'Number of results (default: 5)',
              type: ToolParameterType.integer,
              defaultValue: 5,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final query = params['query'] as String;
    final numResults = params['num_results'] as int? ?? 5;

    try {
      final response = await _dio.get(
        'https://html.duckduckgo.com/html/',
        queryParameters: {'q': query},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
          },
          responseType: ResponseType.plain,
        ),
      );

      final results = _parseSearchResults(response.data.toString(), numResults);

      if (results.isEmpty) {
        return ToolResult.success('No results found for: $query');
      }

      return ToolResult.success(results);
    } catch (e) {
      return ToolResult.error('Search failed: $e');
    }
  }

  List<Map<String, String>> _parseSearchResults(String html, int maxResults) {
    final results = <Map<String, String>>[];
    final linkPattern = RegExp(r'<a[^>]+class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>');
    final snippetPattern = RegExp(r'<a[^>]+class="result__snippet"[^>]*>(.*?)</a>');

    final links = linkPattern.allMatches(html).toList();
    final snippets = snippetPattern.allMatches(html).toList();

    for (var i = 0; i < links.length && results.length < maxResults; i++) {
      final link = links[i];
      final snippet = i < snippets.length ? snippets[i].group(1) ?? '' : '';

      results.add({
        'title': _cleanHtml(link.group(2) ?? ''),
        'url': link.group(1) ?? '',
        'snippet': _cleanHtml(snippet),
      });
    }

    return results;
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('\n', ' ')
        .trim();
  }
}

List<Tool> getAllWebTools() {
  return [WebFetchTool(), WebSearchTool()];
}
