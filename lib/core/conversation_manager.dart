import 'package:nextron_ai/core/ai_engine.dart';
import 'package:nextron_ai/core/memory_system.dart';

class ConversationManager {
  static const int _maxMessages = 20;
  static const int _summarizeThreshold = 40;
  static const String _defaultSessionId = 'jarvis_current_session';
  
  final AIEngine? _aiEngine;
  final MemorySystem? _memorySystem;
  int _messageCount = 0;
  bool _restored = false;
  
  ConversationManager(this._aiEngine, [this._memorySystem]);

  final List<Map<String, String>> _fullMessages = [];
  final List<Map<String, String>> _summaries = [];
  String? _currentSummary;

  /// Restore previous conversation session from SQLite on startup
  Future<void> restoreSession() async {
    if (_memorySystem == null || _restored) return;
    _restored = true;

    try {
      final session = await _memorySystem!.loadLatestConversationSession();
      if (session == null) return;

      final messages = session['messages'] as List<dynamic>;
      final summaries = session['summaries'] as List<dynamic>;

      _fullMessages.clear();
      for (final m in messages) {
        _fullMessages.add({
          'role': m['role'] as String,
          'content': m['content'] as String,
        });
      }

      _summaries.clear();
      for (final s in summaries) {
        _summaries.add({
          'role': s['role'] as String,
          'content': s['content'] as String,
        });
      }

      _currentSummary = session['current_summary'] as String?;
      _messageCount = session['message_count'] as int;
    } catch (_) {}
  }

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

    // Persist to SQLite after every message
    await _persistSession();
  }

  Future<void> _persistSession() async {
    if (_memorySystem == null) return;
    try {
      await _memorySystem!.saveConversationSession(
        sessionId: _defaultSessionId,
        messages: _fullMessages,
        summaries: _summaries,
        currentSummary: _currentSummary,
        messageCount: _messageCount,
      );
    } catch (_) {}
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
      final summary = await _aiEngine!.sendMessage(
        'Summarize this conversation in 2-3 sentences, keeping key facts and emotional context:\n$conversationText',
      );

      if (summary.isNotEmpty) {
        _summaries.add({
          'role': 'assistant',
          'content': summary,
        });
        _currentSummary = summary;
        
        if (_summaries.length > 5) {
          _summaries.removeAt(0);
        }

        // Persist after summarization
        await _persistSession();
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

  Future<void> clear() async {
    _fullMessages.clear();
    _summaries.clear();
    _currentSummary = null;
    _messageCount = 0;
    if (_memorySystem != null) {
      try {
        await _memorySystem!.clearAllConversationSessions();
      } catch (_) {}
    }
  }

  int get messageCount => _messageCount;
  
  int get currentWindowSize => _fullMessages.length;
  
  bool get needsSummarization => _messageCount % _summarizeThreshold == 0 && _messageCount > 0;

  List<Map<String, String>> get recentMessages => List.unmodifiable(_fullMessages);
  
  String? get currentSummary => _currentSummary;
}
