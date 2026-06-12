import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

class WebPage {
  final String url;
  final String title;
  final String content;
  final List<String> links;
  final List<String> images;
  final Map<String, String> metadata;
  final DateTime fetchedAt;

  WebPage({
    required this.url,
    required this.title,
    required this.content,
    this.links = const [],
    this.images = const [],
    this.metadata = const {},
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'content': content,
    'links': links,
    'images': images,
    'metadata': metadata,
    'fetched_at': fetchedAt.toIso8601String(),
  };
}

class FormField {
  final String name;
  final String type;
  final String? value;
  final bool required;

  FormField({
    required this.name,
    required this.type,
    this.value,
    this.required = false,
  });
}

class WebAutomation {
  final Dio _dio = Dio();

  WebAutomation() {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  Future<WebPage> fetchPage(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          responseType: ResponseType.plain,
        ),
      );

      final html = response.data.toString();
      final title = _extractTitle(html);
      final content = _extractContent(html);
      final links = _extractLinks(html, url);
      final images = _extractImages(html, url);
      final metadata = _extractMetadata(html);

      return WebPage(
        url: url,
        title: title,
        content: content,
        links: links,
        images: images,
        metadata: metadata,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch page: $e');
    }
  }

  Future<String> getPageText(String url) async {
    final page = await fetchPage(url);
    return page.content;
  }

  Future<List<String>> getLinks(String url) async {
    final page = await fetchPage(url);
    return page.links;
  }

  Future<void> openInBrowser(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', ['', url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (e) {
      throw Exception('Failed to open URL: $e');
    }
  }

  Future<void> openApp(String appName) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-a', appName]);
      } else if (Platform.isWindows) {
        await Process.run('start', ['', appName]);
      }
    } catch (e) {
      throw Exception('Failed to open app: $e');
    }
  }

  String _extractTitle(String html) {
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
        .firstMatch(html);
    return titleMatch?.group(1)?.trim() ?? 'Untitled';
  }

  String _extractContent(String html) {
    var content = html;

    content = content.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
    content = content.replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');
    content = content.replaceAll(RegExp(r'<[^>]+>'), ' ');
    content = content.replaceAll(RegExp(r'\s+'), ' ');
    content = content.replaceAll(RegExp(r'&nbsp;'), ' ');
    content = content.replaceAll(RegExp(r'&amp;'), '&');
    content = content.replaceAll(RegExp(r'&lt;'), '<');
    content = content.replaceAll(RegExp(r'&gt;'), '>');
    content = content.replaceAll(RegExp(r'&quot;'), '"');

    return content.trim();
  }

  List<String> _extractLinks(String html, String baseUrl) {
    final links = <String>{};
    final linkPattern = RegExp(r'<a[^>]+href="([^"]+)"', caseSensitive: false);

    for (final match in linkPattern.allMatches(html)) {
      var href = match.group(1) ?? '';
      if (href.startsWith('http')) {
        links.add(href);
      } else if (href.startsWith('/')) {
        final uri = Uri.parse(baseUrl);
        links.add('${uri.scheme}://${uri.host}$href');
      }
    }

    return links.toList();
  }

  List<String> _extractImages(String html, String baseUrl) {
    final images = <String>{};
    final imgPattern = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);

    for (final match in imgPattern.allMatches(html)) {
      var src = match.group(1) ?? '';
      if (src.startsWith('http')) {
        images.add(src);
      } else if (src.startsWith('/')) {
        final uri = Uri.parse(baseUrl);
        images.add('${uri.scheme}://${uri.host}$src');
      }
    }

    return images.toList();
  }

  Map<String, String> _extractMetadata(String html) {
    final metadata = <String, String>{};
    final metaPattern = RegExp(r'<meta[^>]+name="([^"]+)"[^>]+content="([^"]+)"', caseSensitive: false);

    for (final match in metaPattern.allMatches(html)) {
      final name = match.group(1) ?? '';
      final content = match.group(2) ?? '';
      if (name.isNotEmpty && content.isNotEmpty) {
        metadata[name] = content;
      }
    }

    return metadata;
  }

  Future<bool> isUrlAccessible(String url) async {
    try {
      final response = await _dio.head(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>> getHeaders(String url) async {
    try {
      final response = await _dio.head(url);
      return response.headers.map
          .map((key, values) => MapEntry(key, values.join(', ')));
    } catch (e) {
      return {};
    }
  }
}
