import 'package:dio/dio.dart';

class VectorEmbedding {
  final String id;
  final List<double> values;
  final String text;
  final String category;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  VectorEmbedding({
    required this.id,
    required this.values,
    required this.text,
    this.category = 'general',
    this.metadata = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'values': values,
    'text': text,
    'category': category,
    'metadata': metadata,
    'created_at': createdAt.toIso8601String(),
  };

  factory VectorEmbedding.fromJson(Map<String, dynamic> json) {
    return VectorEmbedding(
      id: json['id'],
      values: List<double>.from(json['values']),
      text: json['text'],
      category: json['category'] ?? 'general',
      metadata: json['metadata'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class EmbeddingMatch {
  final VectorEmbedding embedding;
  final double score;

  EmbeddingMatch({required this.embedding, required this.score});
}

class VectorEmbeddingService {
  final Dio _dio = Dio();
  String _apiKey = '';
  String _model = 'openai/text-embedding-3-small';
  final Map<String, List<VectorEmbedding>> _store = {};

  VectorEmbeddingService({String? apiKey}) : _apiKey = apiKey ?? '';

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  void setModel(String model) {
    _model = model;
  }

  Future<List<double>> getEmbedding(String text) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key not set for embeddings');
    }

    try {
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/embeddings',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://jarvis-desktop.app',
            'X-Title': 'Jarvis Desktop Agent',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'model': _model,
          'input': text,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['data'] != null && data['data'].isNotEmpty) {
          return List<double>.from(data['data'][0]['embedding']);
        }
      }
      throw Exception('Failed to get embedding: ${response.statusCode}');
    } catch (e) {
      throw Exception('Embedding failed: $e');
    }
  }

  Future<List<VectorEmbedding>> getEmbeddings(List<String> texts) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key not set for embeddings');
    }

    try {
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/embeddings',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://jarvis-desktop.app',
            'X-Title': 'Jarvis Desktop Agent',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'model': _model,
          'input': texts,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['data'] != null) {
          return (data['data'] as List).map((item) {
            final idx = item['index'] ?? 0;
            return VectorEmbedding(
              id: 'emb_${DateTime.now().millisecondsSinceEpoch}_$idx',
              values: List<double>.from(item['embedding']),
              text: texts[idx],
              createdAt: DateTime.now(),
            );
          }).toList();
        }
      }
      throw Exception('Failed to get embeddings: ${response.statusCode}');
    } catch (e) {
      throw Exception('Batch embedding failed: $e');
    }
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (normA * normB);
  }

  void store(String category, VectorEmbedding embedding) {
    _store.putIfAbsent(category, () => []).add(embedding);
  }

  void storeAll(String category, List<VectorEmbedding> embeddings) {
    _store.putIfAbsent(category, () => []).addAll(embeddings);
  }

  List<EmbeddingMatch> search(
    List<double> queryEmbedding, {
    int topK = 5,
    String? category,
    double minScore = 0.0,
  }) {
    final results = <EmbeddingMatch>[];

    final categoriesToSearch = category != null
        ? [category]
        : _store.keys.toList();

    for (final cat in categoriesToSearch) {
      final embeddings = _store[cat] ?? [];
      for (final emb in embeddings) {
        final score = cosineSimilarity(queryEmbedding, emb.values);
        if (score >= minScore) {
          results.add(EmbeddingMatch(embedding: emb, score: score));
        }
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  Future<List<EmbeddingMatch>> searchByText(
    String query, {
    int topK = 5,
    String? category,
    double minScore = 0.3,
  }) async {
    final queryEmbedding = await getEmbedding(query);
    return search(
      queryEmbedding,
      topK: topK,
      category: category,
      minScore: minScore,
    );
  }

  int get totalCount {
    var count = 0;
    for (final embeddings in _store.values) {
      count += embeddings.length;
    }
    return count;
  }

  Map<String, int> get categoryCounts {
    return _store.map((key, value) => MapEntry(key, value.length));
  }

  void clear({String? category}) {
    if (category != null) {
      _store.remove(category);
    } else {
      _store.clear();
    }
  }
}
