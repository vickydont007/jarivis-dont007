import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
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
  VectorEmbeddingService _embeddingService;
  final Map<String, StoredDocument> _documents = {};
  final Map<String, List<VectorEmbedding>> _embeddings = {};
  final StreamController<StoredDocument> _documentController =
      StreamController<StoredDocument>.broadcast();
  
  static Database? _db;

  VectorStore(this._embeddingService);

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/nextron_vectors.db';
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS vectors (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            category TEXT NOT NULL,
            metadata TEXT,
            embedding_values TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_category ON vectors(category)');
      },
    );
  }

  static Future<void> init() async {
    await database;
  }

  void setEmbeddingService(VectorEmbeddingService service) {
    _embeddingService = service;
  }

  Stream<StoredDocument> get documentStream => _documentController.stream;

  Future<void> _saveToSQLite(StoredDocument doc, List<double>? embedding) async {
    try {
      final db = await database;
      await db.insert(
        'vectors',
        {
          'id': doc.id,
          'content': doc.content,
          'category': doc.category,
          'metadata': jsonEncode(doc.metadata),
          'embedding_values': embedding != null ? jsonEncode(embedding) : null,
          'created_at': doc.createdAt.toIso8601String(),
          'updated_at': doc.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Warning: Failed to save vector to SQLite: $e');
    }
  }

  static Future<void> loadFromSQLite(VectorStore store) async {
    try {
      final db = await database;
      final rows = await db.query('vectors');
      
      for (final row in rows) {
        final doc = StoredDocument(
          id: row['id'] as String,
          content: row['content'] as String,
          category: row['category'] as String,
          metadata: row['metadata'] != null 
              ? jsonDecode(row['metadata'] as String) 
              : {},
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: DateTime.parse(row['updated_at'] as String),
        );
        store._documents[doc.id] = doc;

        if (row['embedding_values'] != null) {
          final values = (jsonDecode(row['embedding_values'] as String) as List)
              .map((v) => (v as num).toDouble())
              .toList();
          final vectorEmbedding = VectorEmbedding(
            id: doc.id,
            values: values,
            text: doc.content,
            category: doc.category,
            metadata: doc.metadata,
            createdAt: doc.createdAt,
          );
          store._embeddings.putIfAbsent(doc.category, () => []).add(vectorEmbedding);
          store._embeddingService.store(doc.category, vectorEmbedding);
        }
      }
      print('Loaded ${rows.length} vectors from SQLite');
    } catch (e) {
      print('Warning: Failed to load vectors from SQLite: $e');
    }
  }

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

    List<double>? embeddingValues;
    try {
      final embedding = await _embeddingService.getEmbedding(content);
      embeddingValues = embedding;
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

    await _saveToSQLite(document, embeddingValues);
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

  Future<bool> deleteDocument(String id) async {
    final doc = _documents.remove(id);
    if (doc == null) return false;

    _embeddings[doc.category]?.removeWhere((e) => e.id == id);
    
    try {
      final db = await database;
      await db.delete('vectors', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Warning: Failed to delete vector from SQLite: $e');
    }
    
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

  Future<void> clear({String? category}) async {
    if (category != null) {
      _documents.removeWhere((_, doc) => doc.category == category);
      _embeddings.remove(category);
      _embeddingService.clear(category: category);
      try {
        final db = await database;
        await db.delete('vectors', where: 'category = ?', whereArgs: [category]);
      } catch (e) {
        print('Warning: Failed to clear vectors from SQLite: $e');
      }
    } else {
      _documents.clear();
      _embeddings.clear();
      _embeddingService.clear();
      try {
        final db = await database;
        await db.delete('vectors');
      } catch (e) {
        print('Warning: Failed to clear all vectors from SQLite: $e');
      }
    }
  }

  void dispose() {
    _documentController.close();
  }
}
