import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DiscoveredArticle {
  final String url;
  final String title;
  final String summary;
  final String topic;
  final DateTime firstSeen;
  final bool isNew;

  DiscoveredArticle({
    required this.url,
    required this.title,
    required this.summary,
    required this.topic,
    required this.firstSeen,
    this.isNew = true,
  });
}

class WatchlistMonitor {
  static Database? _database;
  static const _dbName = 'nextron_watchlist_articles.db';
  final Dio _dio = Dio();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE discovered_articles(
            url TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            summary TEXT NOT NULL,
            topic TEXT NOT NULL,
            first_seen TEXT NOT NULL,
            is_alerted INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_topic ON discovered_articles(topic)
        ''');
      },
    );
  }

  Future<List<DiscoveredArticle>> searchTopic(String topic) async {
    final articles = <DiscoveredArticle>[];
    final seenUrls = await _getSeenUrls();

    try {
      final searchResults = await _searchWeb(topic);

      for (final result in searchResults) {
        final url = result['url'] ?? '';
        final title = result['title'] ?? '';
        if (url.isEmpty || title.isEmpty) continue;
        if (seenUrls.contains(url)) continue;

        final content = await _fetchArticle(url);
        final summary = _summarize(content, title);
        await _storeArticle(url, title, summary, topic);

        articles.add(DiscoveredArticle(
          url: url,
          title: title,
          summary: summary,
          topic: topic,
          firstSeen: DateTime.now(),
          isNew: true,
        ));
      }
    } catch (e) {
      // Return what we found
    }

    return articles;
  }

  Future<List<Map<String, String>>> _searchWeb(String query) async {
    final results = <Map<String, String>>[];
    try {
      final response = await _dio.get(
        'https://lite.duckduckgo.com/lite/',
        queryParameters: {'q': '$query 2025 2026'},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
          },
        ),
      );

      final html = response.data.toString();
      final linkRegex = RegExp(
        r'<a[^>]*href="([^"]*)"[^>]*class="result-link"[^>]*>(.*?)</a>',
        caseSensitive: false,
      );
      final snippetRegex = RegExp(
        r'<td[^>]*class="result-snippet"[^>]*>(.*?)</td>',
        caseSensitive: false,
      );

      final links = linkRegex.allMatches(html).toList();
      final snippets = snippetRegex.allMatches(html).toList();

      for (var i = 0; i < links.length && i < 5; i++) {
        var url = links[i].group(1) ?? '';
        var title = links[i].group(2) ?? '';
        var snippet = i < snippets.length ? _stripTags(snippets[i].group(1) ?? '') : '';

        // Clean and validate URL
        url = url.trim();
        title = _stripTags(title).trim();
        snippet = snippet.trim();

        if (url.startsWith('/')) {
          url = 'https://duckduckgo.com$url';
        }

        if (url.isNotEmpty && title.isNotEmpty && !_isUrlBlacklisted(url)) {
          results.add({'url': url, 'title': title, 'snippet': snippet});
        }
      }
    } catch (e) {
      // Fallback to first result only
    }
    return results;
  }

  Future<String> _fetchArticle(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      var content = response.data.toString();
      content = content
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return content.length > 2000 ? content.substring(0, 2000) : content;
    } catch (e) {
      return '';
    }
  }

  String _summarize(String content, String title) {
    if (content.isEmpty) return title;

    // Extract first meaningful paragraph (~3 sentences)
    final sentences = content.split(RegExp(r'[.!?]\s+'));
    var summary = sentences.take(3).join('. ');
    if (sentences.length > 3) summary += '.';

    if (summary.length > 300) {
      summary = '${summary.substring(0, 300)}...';
    }

    return summary;
  }

  Future<Set<String>> _getSeenUrls() async {
    final db = await database;
    final results = await db.query('discovered_articles', columns: ['url']);
    return results.map((r) => r['url'] as String).toSet();
  }

  Future<void> _storeArticle(String url, String title, String summary, String topic) async {
    final db = await database;
    await db.insert('discovered_articles', {
      'url': url,
      'title': title,
      'summary': summary,
      'topic': topic,
      'first_seen': DateTime.now().toIso8601String(),
      'is_alerted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<DiscoveredArticle>> getUnalertedArticles({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'discovered_articles',
      where: 'is_alerted = 0',
      orderBy: 'first_seen DESC',
      limit: limit,
    );
    return results.map((r) => DiscoveredArticle(
      url: r['url'] as String,
      title: r['title'] as String,
      summary: r['summary'] as String,
      topic: r['topic'] as String,
      firstSeen: DateTime.parse(r['first_seen'] as String),
      isNew: true,
    )).toList();
  }

  Future<void> markAlerted(String url) async {
    final db = await database;
    await db.update('discovered_articles', {'is_alerted': 1},
        where: 'url = ?', whereArgs: [url]);
  }

  Future<List<DiscoveredArticle>> getArticlesByTopic(String topic) async {
    final db = await database;
    final results = await db.query(
      'discovered_articles',
      where: 'topic = ?',
      whereArgs: [topic],
      orderBy: 'first_seen DESC',
    );
    return results.map((r) => DiscoveredArticle(
      url: r['url'] as String,
      title: r['title'] as String,
      summary: r['summary'] as String,
      topic: r['topic'] as String,
      firstSeen: DateTime.parse(r['first_seen'] as String),
      isNew: (r['is_alerted'] as int) == 0,
    )).toList();
  }

  Future<int> getArticleCount(String topic) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM discovered_articles WHERE topic = ?',
      [topic],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> searchArticles(String query) async {
    final db = await database;
    final results = await db.query(
      'discovered_articles',
      where: 'title LIKE ? OR summary LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'first_seen DESC',
      limit: 20,
    );
    return results;
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isUrlBlacklisted(String url) {
    const blacklisted = [
      'google.com/search', 'youtube.com', 'facebook.com',
      'twitter.com', 'instagram.com', 'pinterest.com',
      'linkedin.com', 'amazon.com', 'ebay.com',
    ];
    return blacklisted.any((b) => url.contains(b));
  }
}
