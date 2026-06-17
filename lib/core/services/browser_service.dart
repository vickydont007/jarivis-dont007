import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class SearchResult {
  final String title;
  final String url;
  final String snippet;
  final String source;
  final double score;

  SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.source = 'web',
    this.score = 1.0,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'snippet': snippet,
    'source': source,
    'score': score,
  };

  factory SearchResult.fromMap(Map<String, dynamic> map) => SearchResult(
    title: map['title'] ?? '',
    url: map['url'] ?? '',
    snippet: map['snippet'] ?? '',
    source: map['source'] ?? 'web',
    score: (map['score'] as num?)?.toDouble() ?? 1.0,
  );
}

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

  String get summary => content.length > 500 ? '${content.substring(0, 500)}...' : content;
  int get wordCount => content.split(RegExp(r'\s+')).length;
}

class BrowserService {
  static Database? _database;
  static const _dbName = 'nextron_research.db';
  final _uuid = const Uuid();
  String _currentUserId = '';

  void setUserId(String id) {
    _currentUserId = id;
  }

  final Dio _dio;

  BrowserService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE research_sources(
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            domain TEXT NOT NULL,
            credibility_score REAL DEFAULT 0.5,
            visit_count INTEGER DEFAULT 1,
            last_visited TEXT NOT NULL,
            created_at TEXT NOT NULL,
            user_id TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE research_reports(
            id TEXT PRIMARY KEY,
            topic TEXT NOT NULL,
            report_json TEXT NOT NULL,
            sources_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            user_id TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('CREATE INDEX idx_sources_domain ON research_sources(domain)');
        await db.execute('CREATE INDEX idx_reports_topic ON research_reports(topic)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try { await db.execute("ALTER TABLE research_sources ADD COLUMN user_id TEXT NOT NULL DEFAULT ''"); } catch (_) {}
          try { await db.execute("ALTER TABLE research_reports ADD COLUMN user_id TEXT NOT NULL DEFAULT ''"); } catch (_) {}
        }
      },
    );
  }

  // ─── Web Search ───────────────────────────────────────────────

  Future<List<SearchResult>> search(String query, {int limit = 10}) async {
    final results = <SearchResult>[];

    // Tier 1: DuckDuckGo Instant Answer
    try {
      final instant = await _searchInstantAnswer(query);
      results.addAll(instant);
    } catch (_) {}

    // Tier 2: DuckDuckGo HTML
    if (results.length < limit) {
      try {
        final html = await _searchHtml(query, limit: limit - results.length);
        results.addAll(html);
      } catch (_) {}
    }

    // Tier 3: DuckDuckGo Lite
    if (results.length < limit) {
      try {
        final lite = await _searchLite(query, limit: limit - results.length);
        results.addAll(lite);
      } catch (_) {}
    }

    // Deduplicate by URL
    final seen = <String>{};
    final unique = results.where((r) {
      if (seen.contains(r.url)) return false;
      seen.add(r.url);
      return true;
    }).take(limit).toList();

    return unique;
  }

  Future<List<SearchResult>> _searchInstantAnswer(String query) async {
    final response = await _dio.get(
      'https://api.duckduckgo.com/',
      queryParameters: {'q': query, 'format': 'json', 'no_html': 1, 'skip_disambig': 1},
    );

    final results = <SearchResult>[];
    final data = response.data as Map<String, dynamic>;

    final abstract = data['AbstractText'] as String?;
    final abstractUrl = data['AbstractURL'] as String?;
    if (abstract != null && abstract.isNotEmpty && abstractUrl != null) {
      results.add(SearchResult(
        title: data['Heading'] ?? query,
        url: abstractUrl,
        snippet: abstract,
        source: 'duckduckgo_instant',
      ));
    }

    final answer = data['Answer'] as String?;
    final answerUrl = data['AnswerURL'] as String?;
    if (answer != null && answer.isNotEmpty && answerUrl != null) {
      results.add(SearchResult(
        title: 'Answer: $query',
        url: answerUrl,
        snippet: answer,
        source: 'duckduckgo_instant',
      ));
    }

    final related = data['RelatedTopics'] as List?;
    if (related != null) {
      for (final topic in related.take(5)) {
        if (topic is Map && topic['Text'] != null && topic['FirstURL'] != null) {
          results.add(SearchResult(
            title: topic['Text'].toString().substring(0, (topic['Text'].toString().length).clamp(0, 80)),
            url: topic['FirstURL'],
            snippet: topic['Text'],
            source: 'duckduckgo_instant',
          ));
        }
      }
    }

    return results;
  }

  Future<List<SearchResult>> _searchHtml(String query, {int limit = 5}) async {
    final response = await _dio.get(
      'https://html.duckduckgo.com/html/',
      queryParameters: {'q': query},
    );

    final html = response.data.toString();
    final results = <SearchResult>[];

    final linkPattern = RegExp(r'class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>', dotAll: true);
    final snippetPattern = RegExp(r'class="result__snippet"[^>]*>(.*?)</[^>]*>', dotAll: true);

    final links = linkPattern.allMatches(html).toList();
    final snippets = snippetPattern.allMatches(html).toList();

    for (var i = 0; i < links.length && i < limit; i++) {
      var url = links[i].group(1) ?? '';
      final title = _cleanHtml(links[i].group(2) ?? '');
      final snippet = i < snippets.length ? _cleanHtml(snippets[i].group(1) ?? '') : '';

      // Extract real URL from DuckDuckGo redirect
      if (url.contains('uddg=')) {
        final uddg = Uri.parse(url).queryParameters['uddg'];
        if (uddg != null) url = Uri.decodeComponent(uddg);
      }

      if (url.isNotEmpty && title.isNotEmpty) {
        results.add(SearchResult(
          title: title,
          url: url,
          snippet: snippet,
          source: 'duckduckgo_html',
        ));
      }
    }

    return results;
  }

  Future<List<SearchResult>> _searchLite(String query, {int limit = 5}) async {
    final response = await _dio.get(
      'https://lite.duckduckgo.com/lite/',
      queryParameters: {'q': query},
    );

    final html = response.data.toString();
    final results = <SearchResult>[];

    final linkPattern = RegExp(r'<a[^>]*rel="nofollow"[^>]*href="([^"]*)"[^>]*>(.*?)</a>', dotAll: true);
    final snippetPattern = RegExp(r'class="result-snippet">(.*?)</td>', dotAll: true);

    final links = linkPattern.allMatches(html).toList();
    final snippets = snippetPattern.allMatches(html).toList();

    for (var i = 0; i < links.length && i < limit; i++) {
      final url = links[i].group(1) ?? '';
      final title = _cleanHtml(links[i].group(2) ?? '');
      final snippet = i < snippets.length ? _cleanHtml(snippets[i].group(1) ?? '') : '';

      if (url.isNotEmpty && title.isNotEmpty && !url.contains('duckduckgo.com')) {
        results.add(SearchResult(
          title: title,
          url: url,
          snippet: snippet,
          source: 'duckduckgo_lite',
        ));
      }
    }

    return results;
  }

  // ─── Page Fetching ────────────────────────────────────────────

  Future<WebPage> fetchPage(String url) async {
    final response = await _dio.get(url);
    final html = response.data.toString();

    final title = _extractTitle(html);
    final content = _extractContent(html);
    final links = _extractLinks(html, url);
    final images = _extractImages(html, url);
    final metadata = _extractMetadata(html);

    await _trackSource(url, title);

    return WebPage(
      url: url,
      title: title,
      content: content,
      links: links,
      images: images,
      metadata: metadata,
      fetchedAt: DateTime.now(),
    );
  }

  Future<String> getPageContent(String url, {int maxLength = 5000}) async {
    final page = await fetchPage(url);
    return page.content.length > maxLength
        ? '${page.content.substring(0, maxLength)}...'
        : page.content;
  }

  Future<List<String>> getPageLinks(String url) async {
    final page = await fetchPage(url);
    return page.links;
  }

  Future<String> summarizePage(String url) async {
    final page = await fetchPage(url);
    final sentences = page.content.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 10).toList();
    final summary = sentences.take(5).join('. ');
    return '## ${page.title}\n\n$summary.\n\nSource: $url';
  }

  // ─── Source Tracking ──────────────────────────────────────────

  Future<void> _trackSource(String url, String title) async {
    try {
      final db = await database;
      final domain = Uri.parse(url).host;
      final credibility = calculateCredibility(domain);

      await db.insert('research_sources', {
        'id': _uuid.v4(),
        'url': url,
        'title': title,
        'domain': domain,
        'credibility_score': credibility,
        'last_visited': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'user_id': _currentUserId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // Update visit count
      await db.rawUpdate(
        'UPDATE research_sources SET visit_count = visit_count + 1, last_visited = ? WHERE url = ?',
        [DateTime.now().toIso8601String(), url],
      );
    } catch (_) {}
  }

  double calculateCredibility(String domain) {
    final highCredibility = [
      'wikipedia.org', 'github.com', 'stackoverflow.com', 'arxiv.org',
      'Nature.com', 'Science.com', 'ieee.org', 'acm.org',
      'reuters.com', 'apnews.com', 'bbc.com', 'nytimes.com',
      'techcrunch.com', 'theverge.com', 'arstechnica.com',
      'docs.google.com', 'developer.mozilla.org',
    ];
    final mediumCredibility = [
      'medium.com', 'dev.to', 'linkedin.com', 'reddit.com',
      'quora.com', 'youtube.com', 'twitter.com',
    ];

    if (highCredibility.any((d) => domain.contains(d))) return 0.9;
    if (mediumCredibility.any((d) => domain.contains(d))) return 0.6;
    if (domain.endsWith('.edu')) return 0.85;
    if (domain.endsWith('.gov')) return 0.95;
    return 0.5;
  }

  Future<List<Map<String, dynamic>>> getTopSources({int limit = 20}) async {
    final db = await database;
    return await db.query(
      'research_sources',
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
      orderBy: 'credibility_score DESC, visit_count DESC',
      limit: limit,
    );
  }

  // ─── HTML Parsing Helpers ─────────────────────────────────────

  String _extractTitle(String html) {
    final match = RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true).firstMatch(html);
    return match != null ? _cleanHtml(match.group(1) ?? '') : 'Untitled';
  }

  String _extractContent(String html) {
    return html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<nav[^>]*>.*?</nav>', dotAll: true), '')
        .replaceAll(RegExp(r'<footer[^>]*>.*?</footer>', dotAll: true), '')
        .replaceAll(RegExp(r'<header[^>]*>.*?</header>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _extractLinks(String html, String baseUrl) {
    final links = <String>[];
    final pattern = RegExp(r'<a[^>]*href="([^"]*)"[^>]*>', dotAll: true);
    final baseUri = Uri.parse(baseUrl);

    for (final match in pattern.allMatches(html)) {
      var href = match.group(1) ?? '';
      if (href.isEmpty || href.startsWith('#') || href.startsWith('javascript:')) continue;

      try {
        if (href.startsWith('/')) {
          href = '${baseUri.scheme}://${baseUri.host}$href';
        } else if (!href.startsWith('http')) {
          href = '$baseUrl/$href';
        }
        links.add(href);
      } catch (_) {}
    }

    return links.take(50).toList();
  }

  List<String> _extractImages(String html, String baseUrl) {
    final images = <String>[];
    final pattern = RegExp(r'<img[^>]*src="([^"]*)"[^>]*>', dotAll: true);
    final baseUri = Uri.parse(baseUrl);

    for (final match in pattern.allMatches(html)) {
      var src = match.group(1) ?? '';
      if (src.isEmpty) continue;

      try {
        if (src.startsWith('/')) {
          src = '${baseUri.scheme}://${baseUri.host}$src';
        } else if (!src.startsWith('http')) {
          src = '$baseUrl/$src';
        }
        images.add(src);
      } catch (_) {}
    }

    return images.take(20).toList();
  }

  Map<String, String> _extractMetadata(String html) {
    final metadata = <String, String>{};
    final pattern = RegExp(r'<meta[^>]*name="([^"]*)"[^>]*content="([^"]*)"[^>]*>', dotAll: true);

    for (final match in pattern.allMatches(html)) {
      final name = match.group(1) ?? '';
      final content = match.group(2) ?? '';
      if (name.isNotEmpty && content.isNotEmpty) {
        metadata[name] = content;
      }
    }

    return metadata;
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&[^;]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() {
    _dio.close();
  }
}
