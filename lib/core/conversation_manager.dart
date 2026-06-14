import 'package:nextron_ai/core/ai_engine.dart';

class ConversationManager {
  static const int _maxMessages = 20;
  static const int _summarizeThreshold = 40;
  
  final AIEngine? _aiEngine;
  int _messageCount = 0;
  
  ConversationManager(this._aiEngine);

  static List<Map<String, String>> _fullMessages = [];
  static List<Map<String, String>> _summaries = [];
  static String? _currentSummary;

  Future<void> addMessage(String role, String content) async {
    _fullMessages.add({
      'role': role,
      'content': content,
    });
    _messageCount++;

    // Keep only last N full messages
    if (_fullMessages.length > _maxMessages) {
      _fullMessages.removeAt(0);
    }

    // Summarize when threshold reached
    if (_messageCount % _summarizeThreshold == 0 && _fullMessages.length >= _maxMessages) {
      await _summarizeOldMessages();
    }
  }

  Future<void> _summarizeOldMessages() async {
    if (_aiEngine == null || _fullMessages.length < 10) return;

    final messagesToSummarize = _fullMessages.sublist(
      0,
      _fullMessages.length - _maxMessages,
    );

    if (messagesToSummarize.isEmpty) return;

    final conversationText = messagesToSummarize
        .map((m) => '${m['role']}: ${m['content']}')
        .join('\n');

    try {
      final summary = await _aiEngine.sendMessage(
        'Summarize this conversation in 2-3 sentences, keeping key facts and emotional context:\n$conversationText',
      );

      if (summary.isNotEmpty) {
        _summaries.add({
          'role': 'assistant',
          'content': summary,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _currentSummary = summary;
        
        if (_summaries.length > 5) {
          _summaries.removeAt(0);
        }
      }
    } catch (e) {}
  }

  List<Map<String, String>> getContextMessages() {
    final context = <Map<String, String>>[];

    // Add current summary if available
    if (_currentSummary != null) {
      context.add({
        'role': 'system',
        'content': 'Previous conversation summary: $_currentSummary',
      });
    }

    // Add all summaries
    for (final summary in _summaries) {
      context.add({
        'role': 'system',
        'content': 'Earlier conversation: ${summary['content']}',
      });
    }

    // Add recent messages
    context.addAll(_fullMessages);

    return context;
  }

  String getFullContext() {
    final buffer = StringBuffer();
    
    if (_currentSummary != null) {
      buffer.writeln('Previous context: $_currentSummary');
    }
    
    for (final msg in _fullMessages) {
      buffer.writeln('${msg['role']}: ${msg['content']}');
    }
    
    return buffer.toString();
  }

  void clear() {
    _fullMessages.clear();
    _summaries.clear();
    _currentSummary = null;
    _messageCount = 0;
  }

  int get messageCount => _messageCount;
  
  int get currentWindowSize => _fullMessages.length;
  
  bool get needsSummarization => _messageCount % _summarizeThreshold == 0 && _messageCount > 0;
}
