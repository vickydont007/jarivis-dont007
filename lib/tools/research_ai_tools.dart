import 'dart:async';
import '../core/services/browser_service.dart';
import '../core/services/research_service.dart';
import '../core/services/source_verification.dart';
import 'tool.dart';

class BrowserSearchTool extends Tool {
  final BrowserService _browser;
  BrowserSearchTool(this._browser)
      : super(
          name: 'browser_search',
          description: 'Search the web for information on any topic',
          parameters: [
            const ToolParameter(name: 'query', description: 'Search query', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'num_results', description: 'Number of results (default: 5)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final query = params['query'] as String;
      final numResults = (params['num_results'] as int?) ?? 5;
      final results = await _browser.search(query, limit: numResults);

      if (results.isEmpty) return ToolResult.success('No results found for "$query"');

      final buffer = StringBuffer('🔍 Search results for "$query":\n\n');
      for (var i = 0; i < results.length; i++) {
        buffer.writeln('${i + 1}. ${results[i].title}');
        buffer.writeln('   ${results[i].url}');
        buffer.writeln('   ${results[i].snippet}\n');
      }
      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Search failed: $e');
    }
  }
}

class BrowserOpenUrlTool extends Tool {
  final BrowserService _browser;
  BrowserOpenUrlTool(this._browser)
      : super(
          name: 'browser_open_url',
          description: 'Fetch and read content from a web URL',
          parameters: [
            const ToolParameter(name: 'url', description: 'URL to fetch', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'max_length', description: 'Max content length (default: 3000)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final maxLength = (params['max_length'] as int?) ?? 3000;
      final content = await _browser.getPageContent(url, maxLength: maxLength);
      return ToolResult.success('Page content from $url:\n\n$content');
    } catch (e) {
      return ToolResult.error('Failed to fetch URL: $e');
    }
  }
}

class BrowserExtractContentTool extends Tool {
  final BrowserService _browser;
  BrowserExtractContentTool(this._browser)
      : super(
          name: 'browser_extract_content',
          description: 'Extract structured content from a webpage (title, links, images, metadata)',
          parameters: [
            const ToolParameter(name: 'url', description: 'URL to extract from', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final page = await _browser.fetchPage(url);

      final buffer = StringBuffer('📄 ${page.title}\n');
      buffer.writeln('URL: ${page.url}\n');
      buffer.writeln('Content (${page.wordCount} words):');
      buffer.writeln(page.content.length > 2000 ? '${page.content.substring(0, 2000)}...' : page.content);

      if (page.links.isNotEmpty) {
        buffer.writeln('\n📎 Links (${page.links.length}):');
        for (final link in page.links.take(10)) {
          buffer.writeln('  • $link');
        }
      }

      if (page.metadata.isNotEmpty) {
        buffer.writeln('\n📋 Metadata:');
        for (final entry in page.metadata.entries) {
          buffer.writeln('  ${entry.key}: ${entry.value}');
        }
      }

      return ToolResult.success(buffer.toString());
    } catch (e) {
      return ToolResult.error('Failed to extract content: $e');
    }
  }
}

class BrowserSummarizePageTool extends Tool {
  final BrowserService _browser;
  BrowserSummarizePageTool(this._browser)
      : super(
          name: 'browser_summarize_page',
          description: 'Fetch a webpage and generate a concise summary',
          parameters: [
            const ToolParameter(name: 'url', description: 'URL to summarize', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final summary = await _browser.summarizePage(url);
      return ToolResult.success(summary);
    } catch (e) {
      return ToolResult.error('Failed to summarize page: $e');
    }
  }
}

class ResearchTopicTool extends Tool {
  final ResearchService _research;
  ResearchTopicTool(this._research)
      : super(
          name: 'research_topic',
          description: 'Research a topic by gathering information from multiple web sources and generating a structured report',
          parameters: [
            const ToolParameter(name: 'topic', description: 'Topic to research', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'max_sources', description: 'Max sources to consult (default: 10)', type: ToolParameterType.integer),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final topic = params['topic'] as String;
      final maxSources = (params['max_sources'] as int?) ?? 10;
      final report = await _research.researchTopic(topic, maxSources: maxSources);
      return ToolResult.success(report.toMarkdown());
    } catch (e) {
      return ToolResult.error('Research failed: $e');
    }
  }
}

class ResearchCompanyTool extends Tool {
  final ResearchService _research;
  ResearchCompanyTool(this._research)
      : super(
          name: 'research_company',
          description: 'Research a specific company: overview, products, funding, competitors',
          parameters: [
            const ToolParameter(name: 'company', description: 'Company name to research', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final company = params['company'] as String;
      final report = await _research.researchCompany(company);
      return ToolResult.success(report.toMarkdown());
    } catch (e) {
      return ToolResult.error('Company research failed: $e');
    }
  }
}

class ResearchCompetitorsTool extends Tool {
  final ResearchService _research;
  ResearchCompetitorsTool(this._research)
      : super(
          name: 'research_competitors',
          description: 'Research competitors in a specific industry or market',
          parameters: [
            const ToolParameter(name: 'industry', description: 'Industry or market to analyze', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final industry = params['industry'] as String;
      final report = await _research.researchCompetitors(industry);
      return ToolResult.success(report.toMarkdown());
    } catch (e) {
      return ToolResult.error('Competitor research failed: $e');
    }
  }
}

class ResearchMarketTool extends Tool {
  final ResearchService _research;
  ResearchMarketTool(this._research)
      : super(
          name: 'research_market',
          description: 'Research market size, trends, and analysis for a specific market',
          parameters: [
            const ToolParameter(name: 'market', description: 'Market to research', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final market = params['market'] as String;
      final report = await _research.researchMarket(market);
      return ToolResult.success(report.toMarkdown());
    } catch (e) {
      return ToolResult.error('Market research failed: $e');
    }
  }
}

class ResearchTrendsTool extends Tool {
  final ResearchService _research;
  ResearchTrendsTool(this._research)
      : super(
          name: 'research_trends',
          description: 'Research latest trends and developments in a topic area',
          parameters: [
            const ToolParameter(name: 'topic', description: 'Topic to research trends for', type: ToolParameterType.string, required: true),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final topic = params['topic'] as String;
      final report = await _research.researchTrends(topic);
      return ToolResult.success(report.toMarkdown());
    } catch (e) {
      return ToolResult.error('Trend research failed: $e');
    }
  }
}

class ResearchGenerateReportTool extends Tool {
  final ResearchService _research;
  final SourceVerificationService _verification;
  ResearchGenerateReportTool(this._research, this._verification)
      : super(
          name: 'research_generate_report',
          description: 'Generate a formatted research report from gathered sources',
          parameters: [
            const ToolParameter(name: 'topic', description: 'Report topic', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'format', description: 'Output format', type: ToolParameterType.string, enumValues: ['markdown', 'summary']),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final topic = params['topic'] as String;
      final format = (params['format'] as String?) ?? 'markdown';

      final report = await _research.researchTopic(topic);
      final output = format == 'summary'
          ? '## ${report.topic}\n\n${report.executiveSummary}\n\nKey findings: ${report.keyFindings.length}\nSources: ${report.sources.length}'
          : report.toMarkdown();

      return ToolResult.success(output);
    } catch (e) {
      return ToolResult.error('Report generation failed: $e');
    }
  }
}

class ResearchSaveReportTool extends Tool {
  final ResearchService _research;
  ResearchSaveReportTool(this._research)
      : super(
          name: 'research_save_report',
          description: 'Save a research report as markdown content (returns content for file system to save)',
          parameters: [
            const ToolParameter(name: 'topic', description: 'Report topic', type: ToolParameterType.string, required: true),
            const ToolParameter(name: 'filename', description: 'Filename (without extension)', type: ToolParameterType.string),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    try {
      final topic = params['topic'] as String;
      final filename = (params['filename'] as String?) ?? topic.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      final report = await _research.researchTopic(topic);
      final markdown = report.toMarkdown();

      return ToolResult.success(
        'Report generated: "$filename.md"\n\n'
        'To save this report, use the file_write tool with:\n'
        'path: /Users/abc/Research/$filename.md\n'
        'content: (the report below)\n\n'
        '$markdown',
      );
    } catch (e) {
      return ToolResult.error('Failed to generate report: $e');
    }
  }
}

List<Tool> getAllBrowserTools(BrowserService browser) {
  return [
    BrowserSearchTool(browser),
    BrowserOpenUrlTool(browser),
    BrowserExtractContentTool(browser),
    BrowserSummarizePageTool(browser),
  ];
}

List<Tool> getAllResearchTools(ResearchService research, SourceVerificationService verification) {
  return [
    ResearchTopicTool(research),
    ResearchCompanyTool(research),
    ResearchCompetitorsTool(research),
    ResearchMarketTool(research),
    ResearchTrendsTool(research),
    ResearchGenerateReportTool(research, verification),
    ResearchSaveReportTool(research),
  ];
}
