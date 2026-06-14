import 'dart:async';
import 'timeline_service.dart';
import 'memory_service.dart';
import 'memory_search.dart';
import 'external_knowledge.dart';
import '../models/activity_event.dart';
import '../models/memory_record.dart';

class KnowledgeNode {
  final String id;
  final String type;
  final String title;
  final String content;
  final DateTime timestamp;
  final List<String> tags;
  final double relevance;

  KnowledgeNode({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.timestamp,
    this.tags = const [],
    this.relevance = 1.0,
  });
}

class KnowledgeConnection {
  final String fromId;
  final String toId;
  final String relationship;
  final double strength;

  KnowledgeConnection({
    required this.fromId,
    required this.toId,
    required this.relationship,
    this.strength = 1.0,
  });
}

class KnowledgeHub {
  final TimelineService _timeline;
  final MemoryService _memory;
  final MemorySearch _memorySearch;
  final ExternalKnowledge _externalKnowledge;

  KnowledgeHub({
    required TimelineService timeline,
    required MemoryService memory,
    required MemorySearch memorySearch,
    ExternalKnowledge? externalKnowledge,
  })  : _timeline = timeline,
        _memory = memory,
        _memorySearch = memorySearch,
        _externalKnowledge = externalKnowledge ?? ExternalKnowledge();

  Future<Map<String, dynamic>> getUnifiedContext() async {
    final memories = await _memory.recentMemories(limit: 20);
    final events = await _timeline.getRecent(limit: 20);
    final now = DateTime.now();

    final todayMemories = memories.where((m) =>
      m.createdAt.year == now.year &&
      m.createdAt.month == now.month &&
      m.createdAt.day == now.day,
    ).toList();

    final todayEvents = events.where((e) =>
      e.timestamp.year == now.year &&
      e.timestamp.month == now.month &&
      e.timestamp.day == now.day,
    ).toList();

    final topCategories = _analyzeCategories(memories);
    final recentTopics = _extractTopics(memories);

    Map<String, int> externalStats = {};
    try {
      externalStats = await _externalKnowledge.getIngestionStats();
    } catch (e) {
    }

    return {
      'totalMemories': memories.length,
      'totalEvents': events.length,
      'todayMemories': todayMemories.length,
      'todayEvents': todayEvents.length,
      'topCategories': topCategories,
      'recentTopics': recentTopics,
      'mood': _inferMood(events),
      'activityLevel': _activityLevel(events),
      'externalKnowledge': externalStats,
    };
  }

  Future<List<KnowledgeNode>> searchAcrossAll(String query) async {
    final results = <KnowledgeNode>[];

    final memoryResults = await _memorySearch.search(query, limit: 10);
    for (final mem in memoryResults) {
      results.add(KnowledgeNode(
        id: mem.memoryId,
        type: 'memory',
        title: mem.category,
        content: mem.content,
        timestamp: mem.createdAt,
        tags: [mem.category],
        relevance: mem.score,
      ));
    }

    final events = await _timeline.getRecent(limit: 100);
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    for (final event in events) {
      final text = '${event.title} ${event.description}'.toLowerCase();
      final matches = queryWords.where((w) => text.contains(w)).length;
      if (matches > 0) {
        results.add(KnowledgeNode(
          id: event.id,
          type: 'event',
          title: event.title,
          content: event.description,
          timestamp: event.timestamp,
          tags: [event.source, event.type.name],
          relevance: matches / queryWords.length,
        ));
      }
    }

    try {
      final externalResults = await _externalKnowledge.search(query, limit: 10);
      for (final ext in externalResults) {
        results.add(KnowledgeNode(
          id: ext.id,
          type: ext.type,
          title: ext.title,
          content: ext.content,
          timestamp: ext.ingestedAt,
          tags: ext.tags,
          relevance: 0.8,
        ));
      }
    } catch (e) {
    }

    results.sort((a, b) => b.relevance.compareTo(a.relevance));
    return results.take(20).toList();
  }

  Future<List<KnowledgeConnection>> findConnections(String nodeId) async {
    final connections = <KnowledgeConnection>[];

    // Find related memories
    final memories = await _memory.recentMemories(limit: 50);
    for (final memory in memories) {
      if (memory.id == nodeId) continue;
      final related = await _memorySearch.search(memory.content, limit: 3);
      for (final rel in related) {
        if (rel.memoryId == nodeId) {
          connections.add(KnowledgeConnection(
            fromId: nodeId,
            toId: memory.id,
            relationship: 'related_to',
            strength: rel.score,
          ));
        }
      }
    }

    return connections;
  }

  Map<String, int> _analyzeCategories(List<MemoryRecord> memories) {
    final categories = <String, int>{};
    for (final memory in memories) {
      final cat = memory.type.name;
      categories[cat] = (categories[cat] ?? 0) + 1;
    }
    return categories;
  }

  List<String> _extractTopics(List<MemoryRecord> memories) {
    final wordFreq = <String, int>{};
    for (final memory in memories) {
      final words = memory.content.toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 4)
          .toList();
      for (final word in words) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    final sorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  String _inferMood(List<ActivityEvent> events) {
    final completed = events.where((e) => e.type == ActivityType.agentCompleted).length;
    final failed = events.where((e) => e.type == ActivityType.agentFailed).length;
    final created = events.where((e) => e.type == ActivityType.memoryCreated).length;

    if (failed > completed) return 'Needs attention';
    if (completed > 5) return 'Very productive';
    if (completed > 0) return 'Productive';
    if (created > 0) return 'Learning';
    return 'Quiet';
  }

  String _activityLevel(List<ActivityEvent> events) {
    if (events.length > 20) return 'High';
    if (events.length > 5) return 'Moderate';
    if (events.length > 0) return 'Low';
    return 'Idle';
  }
}
