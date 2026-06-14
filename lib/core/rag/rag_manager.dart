import 'dart:async';
import 'vector_embedding_service.dart';
import 'vector_store.dart';
import '../memory_system.dart';

class RAGManager {
  final VectorEmbeddingService _embeddingService;
  final VectorStore _vectorStore;
  final MemorySystem _memorySystem;
  bool _initialized = false;

  RAGManager({
    required String apiKey,
    required MemorySystem memorySystem,
  })  : _memorySystem = memorySystem,
        _embeddingService = VectorEmbeddingService(apiKey: apiKey),
        _vectorStore = VectorStore(VectorEmbeddingService(apiKey: apiKey)) {
    _vectorStore.setEmbeddingService(_embeddingService);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await VectorStore.init();
      await VectorStore.loadFromSQLite(_vectorStore);
      print('RAGManager initialized with ${_vectorStore.totalCount} vectors loaded');
    } catch (e) {
      print('Warning: Failed to initialize RAGManager: $e');
    }
  }

  void setApiKey(String apiKey) {
    _embeddingService.setApiKey(apiKey);
  }

  VectorStore get vectorStore => _vectorStore;

  Future<void> indexMemory(MemoryEntry memory) async {
    try {
      await _vectorStore.addDocument(
        content: memory.content,
        category: memory.category,
        metadata: {
          'memory_id': memory.id,
          'created_at': memory.createdAt.toIso8601String(),
        },
      );
    } catch (e) {
      print('Warning: Failed to index memory: $e');
    }
  }

  Future<void> indexAllMemories() async {
    try {
      final memories = await _memorySystem.getAllMemories();
      for (final memory in memories) {
        await indexMemory(memory);
      }
    } catch (e) {
      print('Warning: Failed to index all memories: $e');
    }
  }

  Future<List<SearchResult>> semanticSearch(
    String query, {
    int topK = 5,
    String? category,
  }) async {
    return await _vectorStore.search(
      query,
      topK: topK,
      category: category,
      minScore: 0.3,
    );
  }

  Future<String> getRelevantContext(String query, {int maxResults = 3}) async {
    final results = await semanticSearch(query, topK: maxResults);
    if (results.isEmpty) return '';

    final context = results.map((r) {
      final score = (r.score * 100).toStringAsFixed(0);
      return '[${score}% match] ${r.document.content}';
    }).join('\n\n');

    return 'Relevant memories:\n$context';
  }

  Future<void> addDocument({
    required String content,
    String category = 'general',
    Map<String, dynamic> metadata = const {},
  }) async {
    await _vectorStore.addDocument(
      content: content,
      category: category,
      metadata: metadata,
    );
  }

  Future<void> addDocumentsBatch({
    required List<String> contents,
    String category = 'general',
  }) async {
    await _vectorStore.addDocumentsBatch(
      contents: contents,
      category: category,
    );
  }

  Map<String, dynamic> getStats() {
    return _vectorStore.getStats();
  }

  void clear({String? category}) {
    _vectorStore.clear(category: category);
  }

  void dispose() {
    _vectorStore.dispose();
  }
}
