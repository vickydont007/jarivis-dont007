import 'dart:async';
import 'package:uuid/uuid.dart';
import 'vector_embedding_service.dart';

class StoredDocument {
  final String id;
  final String content;
  final String category;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  DateTime updatedAt;

  StoredDocument({
    required this.id,
    required this.content,
    this.category = 'general',
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'category': category,
    'metadata': metadata,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory StoredDocument.fromJson(Map<String, dynamic> json) {
    return StoredDocument(
      id: json['id'],
      content: json['content'],
      category: json['category'] ?? 'general',
      metadata: json['metadata'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class SearchResult {
  final StoredDocument document;
  final double score;
  final String? snippet;

  SearchResult({required this.document, required this.score, this.snippet});
}

class VectorStore {
  final VectorEmbeddingService _embeddingService;
  final Map<String, StoredDocument> _documents = {};
  final Map<String, List<VectorEmbedding>> _embeddings = {};
  final StreamController<StoredDocument> _documentController =
      StreamController<StoredDocument>.broadcast();

  VectorStore(this._embeddingService);

  Stream<StoredDocument> get documentStream => _documentController.stream;

  Future<String> addDocument({
    required String content,
    String category = 'general',
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final document = StoredDocument(
      id: id,
      content: content,
      category: category,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    _documents[id] = document;

    try {
      final embedding = await _embeddingService.getEmbedding(content);
      final vectorEmbedding = VectorEmbedding(
        id: id,
        values: embedding,
        text: content,
        category: category,
        metadata: metadata,
        createdAt: now,
      );

      _embeddings.putIfAbsent(category, () => []).add(vectorEmbedding);
      _embeddingService.store(category, vectorEmbedding);
    } catch (e) {
      print('Warning: Failed to create embedding for document $id: $e');
    }

    _documentController.add(document);
    return id;
  }

  Future<List<String>> addDocumentsBatch({
    required List<String> contents,
    String category = 'general',
    Map<String, dynamic> Function(int index)? metadataBuilder,
  }) async {
    final ids = <String>[];
    final now = DateTime.now();

    for (var i = 0; i < contents.length; i++) {
      final id = const Uuid().v4();
      final content = contents[i];
      final metadata = metadataBuilder?.call(i) ?? {};

      final document = StoredDocument(
        id: id,
        content: content,
        category: category,
        metadata: metadata,
        createdAt: now,
        updatedAt: now,
      );

      _documents[id] = document;
      ids.add(id);
    }

    try {
      final embeddings = await _embeddingService.getEmbeddings(contents);
      for (var i = 0; i < embeddings.length; i++) {
        final emb = embeddings[i];
        final vectorEmbedding = VectorEmbedding(
          id: ids[i],
          values: emb.values,
          text: contents[i],
          category: category,
          metadata: metadataBuilder?.call(i) ?? {},
          createdAt: now,
        );

        _embeddings.putIfAbsent(category, () => []).add(vectorEmbedding);
        _embeddingService.store(category, vectorEmbedding);
      }
    } catch (e) {
      print('Warning: Failed to create batch embeddings: $e');
    }

    return ids;
  }

  Future<List<SearchResult>> search(
    String query, {
    int topK = 5,
    String? category,
    double minScore = 0.3,
  }) async {
    try {
      final matches = await _embeddingService.searchByText(
        query,
        topK: topK,
        category: category,
        minScore: minScore,
      );

      return matches.map((match) {
        final doc = _documents[match.embedding.id];
        if (doc == null) return null;

        return SearchResult(
          document: doc,
          score: match.score,
          snippet: _extractSnippet(doc.content, query),
        );
      }).whereType<SearchResult>().toList();
    } catch (e) {
      print('Search failed: $e');
      return [];
    }
  }

  String? _extractSnippet(String content, String query, {int maxLength = 200}) {
    final lower = content.toLowerCase();
    final queryLower = query.toLowerCase();
    final index = lower.indexOf(queryLower);

    if (index == -1) {
      return content.length > maxLength
          ? '${content.substring(0, maxLength)}...'
          : content;
    }

    final start = (index - 50).clamp(0, content.length);
    final end = (index + query.length + 150).clamp(0, content.length);

    var snippet = content.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';

    return snippet;
  }

  StoredDocument? getDocument(String id) {
    return _documents[id];
  }

  bool deleteDocument(String id) {
    final doc = _documents.remove(id);
    if (doc == null) return false;

    _embeddings[doc.category]?.removeWhere((e) => e.id == id);
    return true;
  }

  bool updateDocument(String id, {String? newContent, Map<String, dynamic>? metadata}) {
    final doc = _documents[id];
    if (doc == null) return false;

    doc.updatedAt = DateTime.now();

    return true;
  }

  List<StoredDocument> getDocumentsByCategory(String category) {
    return _documents.values.where((d) => d.category == category).toList();
  }

  List<StoredDocument> getAllDocuments() {
    return _documents.values.toList();
  }

  int get totalCount => _documents.length;

  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final doc in _documents.values) {
      counts[doc.category] = (counts[doc.category] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> getStats() {
    return {
      'total_documents': totalCount,
      'categories': categoryCounts,
      'total_embeddings': _embeddingService.totalCount,
      'embedding_categories': _embeddingService.categoryCounts,
    };
  }

  void clear({String? category}) {
    if (category != null) {
      _documents.removeWhere((_, doc) => doc.category == category);
      _embeddings.remove(category);
      _embeddingService.clear(category: category);
    } else {
      _documents.clear();
      _embeddings.clear();
      _embeddingService.clear();
    }
  }

  void dispose() {
    _documentController.close();
  }
}
