import 'dart:async';
import 'browser_service.dart';

class VerifiedSource {
  final String url;
  final String title;
  final String domain;
  final double credibilityScore;
  final String credibilityLabel;
  final bool isDuplicate;
  final String? reason;

  VerifiedSource({
    required this.url,
    required this.title,
    required this.domain,
    required this.credibilityScore,
    required this.credibilityLabel,
    this.isDuplicate = false,
    this.reason,
  });
}

class SourceVerificationService {
  final BrowserService _browser;
  final Set<String> _seenUrls = {};

  SourceVerificationService({BrowserService? browser}) : _browser = browser ?? BrowserService();

  List<VerifiedSource> verifySources(List<SearchResult> results) {
    final verified = <VerifiedSource>[];

    for (final result in results) {
      final domain = _extractDomain(result.url);
      final score = _calculateCredibility(domain);
      final isDuplicate = _seenUrls.contains(result.url);

      if (!isDuplicate) _seenUrls.add(result.url);

      verified.add(VerifiedSource(
        url: result.url,
        title: result.title,
        domain: domain,
        credibilityScore: score,
        credibilityLabel: _getLabel(score),
        isDuplicate: isDuplicate,
      ));
    }

    return verified;
  }

  VerifiedSource verifyUrl(String url, {String? title}) {
    final domain = _extractDomain(url);
    final score = _calculateCredibility(domain);
    return VerifiedSource(
      url: url,
      title: title ?? domain,
      domain: domain,
      credibilityScore: score,
      credibilityLabel: _getLabel(score),
    );
  }

  String _extractDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  double _calculateCredibility(String domain) {
    final highTrust = {
      'wikipedia.org': 0.95, 'github.com': 0.9, 'stackoverflow.com': 0.85,
      'arxiv.org': 0.95, 'ieee.org': 0.95, 'acm.org': 0.95,
      'nature.com': 0.98, 'science.org': 0.98, 'cell.com': 0.98,
      'reuters.com': 0.95, 'apnews.com': 0.95, 'bbc.com': 0.9,
      'nytimes.com': 0.9, 'wsj.com': 0.9, 'economist.com': 0.9,
      'techcrunch.com': 0.85, 'theverge.com': 0.85, 'arstechnica.com': 0.85,
      'docs.python.org': 0.9, 'developer.mozilla.org': 0.95,
      'flutter.dev': 0.9, 'dart.dev': 0.9,
    };

    final medTrust = {
      'medium.com': 0.65, 'dev.to': 0.7, 'linkedin.com': 0.7,
      'reddit.com': 0.55, 'quora.com': 0.5, 'youtube.com': 0.6,
      'twitter.com': 0.5, 'x.com': 0.5, 'facebook.com': 0.5,
    };

    for (final entry in highTrust.entries) {
      if (domain.contains(entry.key)) return entry.value;
    }
    for (final entry in medTrust.entries) {
      if (domain.contains(entry.key)) return entry.value;
    }
    if (domain.endsWith('.edu')) return 0.9;
    if (domain.endsWith('.gov')) return 0.95;
    if (domain.endsWith('.org')) return 0.7;

    return 0.5;
  }

  String _getLabel(double score) {
    if (score >= 0.9) return 'Highly Reliable';
    if (score >= 0.75) return 'Reliable';
    if (score >= 0.6) return 'Moderately Reliable';
    if (score >= 0.4) return 'Low Reliability';
    return 'Unverified';
  }

  String generateCitation(VerifiedSource source, int index) {
    return '[$index] ${source.title} - ${source.domain} (Credibility: ${source.credibilityLabel})';
  }

  String generateBibliography(List<VerifiedSource> sources) {
    final buffer = StringBuffer('## Sources & Citations\n\n');
    for (var i = 0; i < sources.length; i++) {
      buffer.writeln('${i + 1}. ${sources[i].title}');
      buffer.writeln('   URL: ${sources[i].url}');
      buffer.writeln('   Domain: ${sources[i].domain}');
      buffer.writeln('   Credibility: ${sources[i].credibilityLabel} (${(sources[i].credibilityScore * 100).round()}%)');
      buffer.writeln('');
    }
    return buffer.toString();
  }

  void reset() {
    _seenUrls.clear();
  }
}
