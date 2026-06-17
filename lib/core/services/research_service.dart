import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'browser_service.dart';

class ResearchReport {
  final String id;
  final String topic;
  final String executiveSummary;
  final List<String> keyFindings;
  final List<ResearchSection> sections;
  final List<ResearchSource> sources;
  final String? recommendations;
  final DateTime createdAt;

  ResearchReport({
    required this.id,
    required this.topic,
    this.executiveSummary = '',
    this.keyFindings = const [],
    this.sections = const [],
    this.sources = const [],
    this.recommendations,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'topic': topic,
    'executiveSummary': executiveSummary,
    'keyFindings': keyFindings,
    'sections': sections.map((s) => s.toMap()).toList(),
    'sources': sources.map((s) => s.toMap()).toList(),
    'recommendations': recommendations,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ResearchReport.fromMap(Map<String, dynamic> map) => ResearchReport(
    id: map['id'] ?? '',
    topic: map['topic'] ?? '',
    executiveSummary: map['executiveSummary'] ?? '',
    keyFindings: List<String>.from(map['keyFindings'] ?? []),
    sections: (map['sections'] as List? ?? []).map((s) => ResearchSection.fromMap(s)).toList(),
    sources: (map['sources'] as List? ?? []).map((s) => ResearchSource.fromMap(s)).toList(),
    recommendations: map['recommendations'],
    createdAt: DateTime.parse(map['createdAt']),
  );

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Research Report: $topic');
    buffer.writeln('*Generated: ${createdAt.toIso8601String().substring(0, 16)}*\n');

    if (executiveSummary.isNotEmpty) {
      buffer.writeln('## Executive Summary\n');
      buffer.writeln('$executiveSummary\n');
    }

    if (keyFindings.isNotEmpty) {
      buffer.writeln('## Key Findings\n');
      for (final finding in keyFindings) {
        buffer.writeln('- $finding');
      }
      buffer.writeln();
    }

    for (final section in sections) {
      buffer.writeln('## ${section.title}\n');
      buffer.writeln('${section.content}\n');
    }

    if (recommendations != null && recommendations!.isNotEmpty) {
      buffer.writeln('## Recommendations\n');
      buffer.writeln('$recommendations\n');
    }

    if (sources.isNotEmpty) {
      buffer.writeln('## Sources\n');
      for (var i = 0; i < sources.length; i++) {
        buffer.writeln('${i + 1}. [${sources[i].title}](${sources[i].url})');
      }
    }

    return buffer.toString();
  }
}

class ResearchSection {
  final String title;
  final String content;

  ResearchSection({required this.title, required this.content});

  Map<String, dynamic> toMap() => {'title': title, 'content': content};
  factory ResearchSection.fromMap(Map<String, dynamic> map) => ResearchSection(
    title: map['title'] ?? '',
    content: map['content'] ?? '',
  );
}

class ResearchSource {
  final String title;
  final String url;
  final String snippet;
  final double credibility;

  ResearchSource({
    required this.title,
    required this.url,
    this.snippet = '',
    this.credibility = 0.5,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'snippet': snippet,
    'credibility': credibility,
  };

  factory ResearchSource.fromMap(Map<String, dynamic> map) => ResearchSource(
    title: map['title'] ?? '',
    url: map['url'] ?? '',
    snippet: map['snippet'] ?? '',
    credibility: (map['credibility'] as num?)?.toDouble() ?? 0.5,
  );
}

class ResearchService {
  final BrowserService _browser;
  final _uuid = const Uuid();

  ResearchService({BrowserService? browser}) : _browser = browser ?? BrowserService();

  BrowserService get browser => _browser;

  void setUserId(String id) {
    _browser.setUserId(id);
  }

  // ─── Topic Research ───────────────────────────────────────────

  Future<ResearchReport> researchTopic(String topic, {int maxSources = 15}) async {
    final searchResults = await _browser.search(topic, limit: maxSources);
    final sources = <ResearchSource>[];
    final contents = <String>[];

    for (final result in searchResults.take(10)) {
      try {
        final page = await _browser.fetchPage(result.url);
        sources.add(ResearchSource(
          title: result.title,
          url: result.url,
          snippet: result.snippet,
          credibility: _browser.calculateCredibility(Uri.parse(result.url).host),
        ));
        contents.add(page.content.length > 3000 ? page.content.substring(0, 3000) : page.content);
      } catch (_) {
        sources.add(ResearchSource(
          title: result.title,
          url: result.url,
          snippet: result.snippet,
        ));
      }
    }

    final findings = _extractKeyFindings(contents, topic);
    final sections = _buildReportSections(topic, contents, searchResults);
    final recommendations = _generateRecommendations(topic, findings);

    return ResearchReport(
      id: _uuid.v4(),
      topic: topic,
      executiveSummary: _generateExecutiveSummary(topic, findings),
      keyFindings: findings,
      sections: sections,
      sources: sources,
      recommendations: recommendations,
      createdAt: DateTime.now(),
    );
  }

  // ─── Company Research ─────────────────────────────────────────

  Future<ResearchReport> researchCompany(String company) async {
    final queries = [
      '$company company overview',
      '$company products services',
      '$company funding valuation',
      '$company competitors market',
    ];

    final allResults = <SearchResult>[];
    for (final query in queries) {
      final results = await _browser.search(query, limit: 5);
      allResults.addAll(results);
    }

    final sources = <ResearchSource>[];
    final contents = <String>[];

    for (final result in allResults.take(12)) {
      try {
        final page = await _browser.fetchPage(result.url);
        sources.add(ResearchSource(
          title: result.title,
          url: result.url,
          snippet: result.snippet,
          credibility: _browser.calculateCredibility(Uri.parse(result.url).host),
        ));
        contents.add(page.content.length > 3000 ? page.content.substring(0, 3000) : page.content);
      } catch (_) {}
    }

    final sections = [
      ResearchSection(title: 'Company Overview', content: _extractSection(contents, 'overview')),
      ResearchSection(title: 'Products & Services', content: _extractSection(contents, 'product')),
      ResearchSection(title: 'Funding & Valuation', content: _extractSection(contents, 'fund')),
      ResearchSection(title: 'Competitive Landscape', content: _extractSection(contents, 'compet')),
    ];

    return ResearchReport(
      id: _uuid.v4(),
      topic: '$company Company Research',
      executiveSummary: 'Research report on $company covering overview, products, funding, and competitive landscape.',
      keyFindings: _extractKeyFindings(contents, company),
      sections: sections.where((s) => s.content.isNotEmpty).toList(),
      sources: sources,
      createdAt: DateTime.now(),
    );
  }

  // ─── Competitor Research ──────────────────────────────────────

  Future<ResearchReport> researchCompetitors(String industry) async {
    final queries = [
      '$industry top companies',
      '$industry market leaders',
      '$industry startup competitors',
    ];

    final allResults = <SearchResult>[];
    for (final query in queries) {
      final results = await _browser.search(query, limit: 5);
      allResults.addAll(results);
    }

    final sources = <ResearchSource>[];
    final contents = <String>[];

    for (final result in allResults.take(10)) {
      try {
        final page = await _browser.fetchPage(result.url);
        sources.add(ResearchSource(
          title: result.title,
          url: result.url,
          snippet: result.snippet,
        ));
        contents.add(page.content.length > 2000 ? page.content.substring(0, 2000) : page.content);
      } catch (_) {}
    }

    return ResearchReport(
      id: _uuid.v4(),
      topic: '$industry Competitor Analysis',
      executiveSummary: 'Competitive landscape analysis for $industry.',
      keyFindings: _extractKeyFindings(contents, industry),
      sections: [
        ResearchSection(title: 'Market Leaders', content: _extractSection(contents, 'leader')),
        ResearchSection(title: 'Emerging Players', content: _extractSection(contents, 'emerging')),
        ResearchSection(title: 'Market Trends', content: _extractSection(contents, 'trend')),
      ],
      sources: sources,
      createdAt: DateTime.now(),
    );
  }

  // ─── Market Research ──────────────────────────────────────────

  Future<ResearchReport> researchMarket(String market) async {
    final queries = [
      '$market market size',
      '$market market trends',
      '$market industry analysis',
    ];

    final allResults = <SearchResult>[];
    for (final query in queries) {
      final results = await _browser.search(query, limit: 5);
      allResults.addAll(results);
    }

    final sources = <ResearchSource>[];
    final contents = <String>[];

    for (final result in allResults.take(10)) {
      try {
        final page = await _browser.fetchPage(result.url);
        sources.add(ResearchSource(
          title: result.title,
          url: result.url,
          snippet: result.snippet,
        ));
        contents.add(page.content.length > 2000 ? page.content.substring(0, 2000) : page.content);
      } catch (_) {}
    }

    return ResearchReport(
      id: _uuid.v4(),
      topic: '$market Market Research',
      executiveSummary: 'Market analysis report for $market.',
      keyFindings: _extractKeyFindings(contents, market),
      sections: [
        ResearchSection(title: 'Market Size & Growth', content: _extractSection(contents, 'size')),
        ResearchSection(title: 'Key Trends', content: _extractSection(contents, 'trend')),
        ResearchSection(title: 'Opportunities & Risks', content: _extractSection(contents, 'opport')),
      ],
      sources: sources,
      createdAt: DateTime.now(),
    );
  }

  // ─── Trend Research ───────────────────────────────────────────

  Future<ResearchReport> researchTrends(String topic) async {
    final query = '$topic latest trends ${DateTime.now().year}';
    final results = await _browser.search(query, limit: 10);

    final sources = <ResearchSource>[];
    final contents = <String>[];

    for (final result in results.take(8)) {
      try {
        final page = await _browser.fetchPage(result.url);
        sources.add(ResearchSource(
          title: result.title,
          url: result.url,
          snippet: result.snippet,
        ));
        contents.add(page.content.length > 2000 ? page.content.substring(0, 2000) : page.content);
      } catch (_) {}
    }

    return ResearchReport(
      id: _uuid.v4(),
      topic: '$topic Trends ${DateTime.now().year}',
      executiveSummary: 'Latest trends and developments in $topic.',
      keyFindings: _extractKeyFindings(contents, topic),
      sections: [
        ResearchSection(title: 'Current Trends', content: _extractSection(contents, 'trend')),
        ResearchSection(title: 'Future Outlook', content: _extractSection(contents, 'future')),
      ],
      sources: sources,
      createdAt: DateTime.now(),
    );
  }

  // ─── Report Helpers ───────────────────────────────────────────

  List<String> _extractKeyFindings(List<String> contents, String topic) {
    final findings = <String>[];
    final combined = contents.join(' ');

    final sentences = combined.split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().length > 20 && s.toLowerCase().contains(topic.toLowerCase()))
        .take(8)
        .toList();

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isNotEmpty && !findings.any((f) => f.contains(trimmed.substring(0, trimmed.length.clamp(0, 30))))) {
        findings.add(trimmed.endsWith('.') ? trimmed : '$trimmed.');
      }
    }

    return findings.isEmpty ? ['No specific findings extracted for $topic'] : findings;
  }

  List<ResearchSection> _buildReportSections(String topic, List<String> contents, List<SearchResult> results) {
    final sections = <ResearchSection>[];

    if (contents.isNotEmpty) {
      sections.add(ResearchSection(
        title: 'Overview',
        content: contents.first.length > 1000 ? contents.first.substring(0, 1000) : contents.first,
      ));
    }

    final combined = contents.join(' ');
    final hasTrends = combined.toLowerCase().contains('trend');
    final hasMarket = combined.toLowerCase().contains('market');
    final hasCompet = combined.toLowerCase().contains('competitor');

    if (hasTrends) sections.add(ResearchSection(title: 'Trends', content: _extractSection(contents, 'trend')));
    if (hasMarket) sections.add(ResearchSection(title: 'Market Analysis', content: _extractSection(contents, 'market')));
    if (hasCompet) sections.add(ResearchSection(title: 'Competitive Landscape', content: _extractSection(contents, 'compet')));

    return sections.isEmpty ? [ResearchSection(title: 'Research Findings', content: 'Research on $topic gathered from ${results.length} sources.')] : sections;
  }

  String _extractSection(List<String> contents, String keyword) {
    for (final content in contents) {
      final lower = content.toLowerCase();
      final idx = lower.indexOf(keyword);
      if (idx != -1) {
        final start = (idx - 100).clamp(0, content.length);
        final end = (idx + 800).clamp(0, content.length);
        return content.substring(start, end);
      }
    }
    return '';
  }

  String _generateExecutiveSummary(String topic, List<String> findings) {
    final summary = StringBuffer('Research on $topic reveals ');
    if (findings.isNotEmpty) {
      summary.writeln('${findings.length} key findings:');
      for (final finding in findings.take(3)) {
        summary.writeln('- $finding');
      }
    } else {
      summary.writeln('that this is an active area of research and development.');
    }
    return summary.toString();
  }

  String _generateRecommendations(String topic, List<String> findings) {
    final buffer = StringBuffer();
    buffer.writeln('Based on the research findings for $topic:');
    buffer.writeln('');
    buffer.writeln('1. Continue monitoring developments in this area');
    if (findings.length > 3) {
      buffer.writeln('2. Deep dive into the top findings for actionable insights');
    }
    buffer.writeln('3. Consider scheduling follow-up research in 30 days');
    return buffer.toString();
  }

  Future<List<ResearchReport>> getRecentReports({int limit = 10}) async {
    try {
      final db = await _browser.database;
      final results = await db.query(
        'research_reports',
        orderBy: 'rowid DESC',
        limit: limit,
      );
      return results.map((r) {
        final json = jsonDecode(r['report_json'] as String);
        return ResearchReport.fromMap(json);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _browser.dispose();
  }
}
