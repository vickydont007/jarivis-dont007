import 'dart:async';
import '../models/memory_record.dart';
import '../services/memory_service.dart';
import '../services/timeline_service.dart';
import '../models/activity_event.dart';

class ExtractedMemory {
  final MemoryType type;
  final String content;
  final List<String> tags;
  final double confidence;
  final String source;
  final int importance;

  const ExtractedMemory({
    required this.type,
    required this.content,
    this.tags = const [],
    this.confidence = 1.0,
    required this.source,
    this.importance = 5,
  });
}

class ExtractionResult {
  final List<ExtractedMemory> memories;
  final String originalText;
  final DateTime extractedAt;
  final double overallConfidence;

  const ExtractionResult({
    required this.memories,
    required this.originalText,
    required this.extractedAt,
    this.overallConfidence = 1.0,
  });
}

class MemoryExtractionPipeline {
  final MemoryService _memoryService;
  final TimelineService _timeline;

  MemoryExtractionPipeline({
    required MemoryService memoryService,
    required TimelineService timeline,
  })  : _memoryService = memoryService,
        _timeline = timeline;

  Future<ExtractionResult> extractFromConversation({
    required String userMessage,
    required String aiResponse,
    String source = 'conversation',
  }) async {
    final memories = <ExtractedMemory>[];

    // Extract from user message
    memories.addAll(_extractFromText(userMessage, source, 'user'));

    // Extract from AI response (facts mentioned)
    memories.addAll(_extractFromText(aiResponse, source, 'ai'));

    // Save extracted memories
    for (final memory in memories) {
      await _memoryService.addMemory(
        type: memory.type,
        content: memory.content,
        tags: memory.tags,
        source: memory.source,
        importance: memory.importance,
      );
    }

    return ExtractionResult(
      memories: memories,
      originalText: '$userMessage\n\n$aiResponse',
      extractedAt: DateTime.now(),
      overallConfidence: memories.isEmpty
          ? 0.0
          : memories.fold(0.0, (sum, m) => sum + m.confidence) / memories.length,
    );
  }

  Future<ExtractionResult> extractFromText({
    required String text,
    String source = 'text',
  }) async {
    final memories = _extractFromText(text, source, 'direct');

    for (final memory in memories) {
      await _memoryService.addMemory(
        type: memory.type,
        content: memory.content,
        tags: memory.tags,
        source: memory.source,
        importance: memory.importance,
      );
    }

    return ExtractionResult(
      memories: memories,
      originalText: text,
      extractedAt: DateTime.now(),
    );
  }

  List<ExtractedMemory> _extractFromText(
    String text,
    String source,
    String role,
  ) {
    final memories = <ExtractedMemory>[];

    // Extract name patterns
    memories.addAll(_extractNames(text, source));

    // Extract preferences
    memories.addAll(_extractPreferences(text, source));

    // Extract dates and events
    memories.addAll(_extractDates(text, source));

    // Extract goals and intentions
    memories.addAll(_extractGoals(text, source));

    // Extract emotions and states
    memories.addAll(_extractEmotions(text, source));

    // Extract factual statements
    memories.addAll(_extractFacts(text, source));

    return memories;
  }

  List<ExtractedMemory> _extractNames(String text, String source) {
    final memories = <ExtractedMemory>[];
    final namePatterns = [
      RegExp(r'my name is (\w+)', caseSensitive: false),
      RegExp(r"i'm (\w+)", caseSensitive: false),
      RegExp(r"i am (\w+)", caseSensitive: false),
      RegExp(r'call me (\w+)', caseSensitive: false),
      RegExp(r"the user's name is (\w+)", caseSensitive: false),
    ];

    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)!;
        memories.add(ExtractedMemory(
          type: MemoryType.fact,
          content: 'User name: $name',
          tags: ['name', 'identity'],
          source: source,
          importance: 8,
        ));
      }
    }

    return memories;
  }

  List<ExtractedMemory> _extractPreferences(String text, String source) {
    final memories = <ExtractedMemory>[];
    final prefPatterns = [
      (pattern: RegExp(r'i (?:prefer|like|love|enjoy) (.+)', caseSensitive: false), tag: 'preference'),
      (pattern: RegExp(r"i don't (?:like|want|prefer) (.+)", caseSensitive: false), tag: 'dislike'),
      (pattern: RegExp(r'my favorite (.+?) is (.+)', caseSensitive: false), tag: 'favorite'),
      (pattern: RegExp(r'i always (.+)', caseSensitive: false), tag: 'habit'),
      (pattern: RegExp(r'i never (.+)', caseSensitive: false), tag: 'habit'),
    ];

    for (final pref in prefPatterns) {
      final match = pref.pattern.firstMatch(text);
      if (match != null) {
        final content = match.group(0)!;
        memories.add(ExtractedMemory(
          type: MemoryType.preference,
          content: content,
          tags: [pref.tag, 'preference'],
          source: source,
          importance: 6,
        ));
      }
    }

    return memories;
  }

  List<ExtractedMemory> _extractDates(String text, String source) {
    final memories = <ExtractedMemory>[];
    final datePatterns = [
      RegExp(r'my birthday is (.+)', caseSensitive: false),
      RegExp(r"birthday[:\s]+(.+)", caseSensitive: false),
      RegExp(r'anniversary[:\s]+(.+)', caseSensitive: false),
      RegExp(r'(?:meeting|appointment|event) on (.+)', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        memories.add(ExtractedMemory(
          type: MemoryType.fact,
          content: match.group(0)!,
          tags: ['date', 'event'],
          source: source,
          importance: 7,
        ));
      }
    }

    return memories;
  }

  List<ExtractedMemory> _extractGoals(String text, String source) {
    final memories = <ExtractedMemory>[];
    final goalPatterns = [
      RegExp(r'i want to (.+)', caseSensitive: false),
      RegExp(r"i'm going to (.+)", caseSensitive: false),
      RegExp(r'i need to (.+)', caseSensitive: false),
      RegExp(r'my goal is to (.+)', caseSensitive: false),
      RegExp(r'i plan to (.+)', caseSensitive: false),
    ];

    for (final pattern in goalPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        memories.add(ExtractedMemory(
          type: MemoryType.goal,
          content: match.group(0)!,
          tags: ['goal', 'intention'],
          source: source,
          importance: 7,
        ));
      }
    }

    return memories;
  }

  List<ExtractedMemory> _extractEmotions(String text, String source) {
    final memories = <ExtractedMemory>[];
    final emotionPatterns = [
      (pattern: RegExp(r"i'm (?:feeling )?(?:very )?happy", caseSensitive: false), emotion: 'happy'),
      (pattern: RegExp(r"i'm (?:feeling )?(?:very )?sad", caseSensitive: false), emotion: 'sad'),
      (pattern: RegExp(r"i'm (?:feeling )?(?:very )?excited", caseSensitive: false), emotion: 'excited'),
      (pattern: RegExp(r"i'm (?:feeling )?(?:very )?tired", caseSensitive: false), emotion: 'tired'),
      (pattern: RegExp(r"i'm (?:feeling )?(?:very )?stressed", caseSensitive: false), emotion: 'stressed'),
      (pattern: RegExp(r"i'm (?:feeling )?(?:very )?frustrated", caseSensitive: false), emotion: 'frustrated'),
    ];

    for (final emotion in emotionPatterns) {
      if (emotion.pattern.hasMatch(text)) {
        memories.add(ExtractedMemory(
          type: MemoryType.pattern,
          content: 'User expressed feeling: ${emotion.emotion}',
          tags: ['emotion', emotion.emotion],
          source: source,
          importance: 5,
        ));
      }
    }

    return memories;
  }

  List<ExtractedMemory> _extractFacts(String text, String source) {
    final memories = <ExtractedMemory>[];
    final factPatterns = [
      RegExp(r'i work (?:at|for|in) (.+)', caseSensitive: false),
      RegExp(r'my job is (.+)', caseSensitive: false),
      RegExp(r'i live in (.+)', caseSensitive: false),
      RegExp(r"i'm a (.+)", caseSensitive: false),
      RegExp(r'i have (.+)', caseSensitive: false),
    ];

    for (final pattern in factPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        memories.add(ExtractedMemory(
          type: MemoryType.fact,
          content: match.group(0)!,
          tags: ['fact', 'personal'],
          source: source,
          importance: 6,
        ));
      }
    }

    return memories;
  }

  Map<String, dynamic> getStats() {
    return {
      'pipeline': 'MemoryExtractionPipeline',
      'strategies': [
        'name_extraction',
        'preference_extraction',
        'date_extraction',
        'goal_extraction',
        'emotion_extraction',
        'fact_extraction',
      ],
    };
  }
}
