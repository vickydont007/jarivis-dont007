import 'package:dio/dio.dart';
import 'tool.dart';

class WebFetchTool extends Tool {
  final Dio _dio = Dio();

  WebFetchTool()
      : super(
          name: 'web_fetch',
          description: 'Fetch content from a URL. Returns the text content of the page.',
          parameters: [
            const ToolParameter(
              name: 'url',
              description: 'URL to fetch (must start with http:// or https://)',
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
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ),
      );

      var content = response.data.toString();

      // Strip HTML tags for cleaner output
      content = content
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (content.length > maxLength) {
        content = '${content.substring(0, maxLength)}... [truncated]';
      }

      if (content.isEmpty) {
        return ToolResult.success('Page fetched but no readable text content found.');
      }

      return ToolResult.success(content, metadata: {
        'status_code': response.statusCode,
        'length': content.length,
      });
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return ToolResult.error('Connection timed out. The website may be slow or unreachable.');
      }
      if (e.type == DioExceptionType.connectionError) {
        return ToolResult.error('Connection failed. Check your internet connection.');
      }
      return ToolResult.error('Failed to fetch URL: ${e.message}');
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
          description: 'Search the web for current/live information. Use this when you need up-to-date data, news, current events, live scores, stock prices, weather, or any real-time information.',
          parameters: [
            const ToolParameter(
              name: 'query',
              description: 'Search query (be specific for better results)',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'num_results',
              description: 'Number of results (default: 5, max: 10)',
              type: ToolParameterType.integer,
              defaultValue: 5,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final query = params['query'] as String;
    final numResults = (params['num_results'] as int? ?? 5).clamp(1, 10);

    // Try DuckDuckGo Instant Answer API first
    final instantResult = await _searchInstantAnswer(query, numResults);
    if (instantResult != null && instantResult.isNotEmpty) {
      return ToolResult.success(instantResult);
    }

    // Fallback: DuckDuckGo HTML scraping
    final htmlResult = await _searchHtml(query, numResults);
    if (htmlResult != null && htmlResult.isNotEmpty) {
      return ToolResult.success(htmlResult);
    }

    // Fallback: DuckDuckGo Lite
    final liteResult = await _searchLite(query, numResults);
    if (liteResult != null && liteResult.isNotEmpty) {
      return ToolResult.success(liteResult);
    }

    return ToolResult.success('No results found for: "$query"\n\nTry rephrasing your search query.');
  }

  Future<String?> _searchInstantAnswer(String query, int maxResults) async {
    try {
      final response = await _dio.get(
        'https://api.duckduckgo.com/',
        queryParameters: {
          'q': query,
          'format': 'json',
          'no_html': '1',
          'skip_disambig': '1',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final results = <String>[];

      // Abstract (main answer)
      final abstract = data['AbstractText'] as String? ?? '';
      if (abstract.isNotEmpty) {
        results.add('**Answer:** $abstract');
      }

      // Answer box
      final answer = data['Answer'] as String? ?? '';
      if (answer.isNotEmpty && answer != abstract) {
        results.add('**Quick Answer:** $answer');
      }

      // Related topics
      final topics = data['RelatedTopics'] as List? ?? [];
      var count = 0;
      for (final topic in topics) {
        if (count >= maxResults) break;
        if (topic is Map<String, dynamic>) {
          final text = topic['Text'] as String? ?? '';
          final FirstURL = topic['FirstURL'] as String? ?? '';
          if (text.isNotEmpty) {
            results.add('• $text${FirstURL.isNotEmpty ? "\n  $FirstURL" : ""}');
            count++;
          }
        }
      }

      // Infobox
      final infobox = data['Infobox'] as Map<String, dynamic>?;
      if (infobox != null) {
        final content = infobox['content'] as List? ?? [];
        for (final item in content) {
          if (item is Map<String, dynamic>) {
            final label = item['label'] as String? ?? '';
            final value = item['value'] as String? ?? '';
            if (label.isNotEmpty && value.isNotEmpty) {
              results.add('• **$label:** $value');
            }
          }
        }
      }

      if (results.isEmpty) return null;
      return 'Search results for "$query":\n\n${results.join("\n")}';
    } catch (e) {
      return null;
    }
  }

  Future<String?> _searchHtml(String query, int maxResults) async {
    try {
      final response = await _dio.get(
        'https://html.duckduckgo.com/html/',
        queryParameters: {'q': query},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          responseType: ResponseType.plain,
        ),
      );

      final results = _parseHtmlResults(response.data.toString(), maxResults);

      if (results.isEmpty) return null;

      final buf = StringBuffer('Search results for "$query":\n\n');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        buf.writeln('${i + 1}. ${r['title']}');
        buf.writeln('   ${r['url']}');
        if (r['snippet']!.isNotEmpty) {
          buf.writeln('   ${r['snippet']}');
        }
        buf.writeln();
      }
      return buf.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> _searchLite(String query, int maxResults) async {
    try {
      final response = await _dio.get(
        'https://lite.duckduckgo.com/lite/',
        queryParameters: {'q': query},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          },
          responseType: ResponseType.plain,
        ),
      );

      final html = response.data.toString();
      final results = <Map<String, String>>[];

      // Parse lite results - simple table format
      final linkPattern = RegExp(r'<a[^>]+rel="nofollow"[^>]+href="([^"]+)"[^>]*>(.*?)</a>');
      final snippetPattern = RegExp(r'<td[^>]*class="result-snippet"[^>]*>(.*?)</td>', dotAll: true);

      final links = linkPattern.allMatches(html).toList();
      final snippets = snippetPattern.allMatches(html).toList();

      for (var i = 0; i < links.length && results.length < maxResults; i++) {
        final link = links[i];
        final url = link.group(1) ?? '';
        final title = _cleanHtml(link.group(2) ?? '');
        final snippet = i < snippets.length ? _cleanHtml(snippets[i].group(1) ?? '') : '';

        if (title.isNotEmpty && url.isNotEmpty) {
          results.add({'title': title, 'url': url, 'snippet': snippet});
        }
      }

      if (results.isEmpty) return null;

      final buf = StringBuffer('Search results for "$query":\n\n');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        buf.writeln('${i + 1}. ${r['title']}');
        buf.writeln('   ${r['url']}');
        if (r['snippet']!.isNotEmpty) {
          buf.writeln('   ${r['snippet']}');
        }
        buf.writeln();
      }
      return buf.toString();
    } catch (e) {
      return null;
    }
  }

  List<Map<String, String>> _parseHtmlResults(String html, int maxResults) {
    final results = <Map<String, String>>[];

    // Try standard DuckDuckGo HTML class patterns
    final linkPattern = RegExp(r'<a[^>]+class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>');
    final snippetPattern = RegExp(r'<a[^>]+class="result__snippet"[^>]*>(.*?)</a>');

    final links = linkPattern.allMatches(html).toList();
    final snippets = snippetPattern.allMatches(html).toList();

    for (var i = 0; i < links.length && results.length < maxResults; i++) {
      final link = links[i];
      final snippet = i < snippets.length ? snippets[i].group(1) ?? '' : '';

      final title = _cleanHtml(link.group(2) ?? '');
      var url = link.group(1) ?? '';

      // DuckDuckGo wraps URLs in redirects - extract actual URL
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (uddgMatch != null) {
        url = Uri.decodeComponent(uddgMatch.group(1)!);
      }

      if (title.isNotEmpty) {
        results.add({
          'title': title,
          'url': url,
          'snippet': _cleanHtml(snippet),
        });
      }
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
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

List<Tool> getAllWebTools() {
  return [WebFetchTool(), WebSearchTool()];
}
