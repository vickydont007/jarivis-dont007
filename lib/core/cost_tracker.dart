import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class APIUsageRecord {
  final String id;
  final String provider;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double cost;
  final DateTime timestamp;
  final String? requestId;

  APIUsageRecord({
    required this.id,
    required this.provider,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.cost,
    required this.timestamp,
    this.requestId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider,
      'model': model,
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
      'cost': cost,
      'timestamp': timestamp.toIso8601String(),
      'request_id': requestId,
    };
  }

  factory APIUsageRecord.fromMap(Map<String, dynamic> map) {
    return APIUsageRecord(
      id: map['id'],
      provider: map['provider'],
      model: map['model'],
      promptTokens: map['prompt_tokens'] ?? 0,
      completionTokens: map['completion_tokens'] ?? 0,
      totalTokens: map['total_tokens'] ?? 0,
      cost: (map['cost'] ?? 0).toDouble(),
      timestamp: DateTime.parse(map['timestamp']),
      requestId: map['request_id'],
    );
  }
}

class CostSummary {
  final double totalCost;
  final int totalTokens;
  final int totalRequests;
  final Map<String, double> costByProvider;
  final Map<String, double> costByModel;
  final Map<String, int> tokensByProvider;

  CostSummary({
    required this.totalCost,
    required this.totalTokens,
    required this.totalRequests,
    required this.costByProvider,
    required this.costByModel,
    required this.tokensByProvider,
  });
}

class CostTracker {
  static Database? _database;
  final StreamController<APIUsageRecord> _recordController =
      StreamController<APIUsageRecord>.broadcast();

  final Map<String, double> _modelPricing = {
    'openai/gpt-4': 0.03,
    'openai/gpt-4-turbo': 0.01,
    'openai/gpt-3.5-turbo': 0.0015,
    'anthropic/claude-3-opus': 0.015,
    'anthropic/claude-3-sonnet': 0.003,
    'google/gemini-pro': 0.001,
    'google/gemma-4-26b-a4b-it:free': 0.0,
    'meta-llama/llama-3.1-8b-instruct:free': 0.0,
  };

  Stream<APIUsageRecord> get recordStream => _recordController.stream;

  CostTracker();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'nextron_cost.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE api_usage(
            id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            prompt_tokens INTEGER DEFAULT 0,
            completion_tokens INTEGER DEFAULT 0,
            total_tokens INTEGER DEFAULT 0,
            cost REAL DEFAULT 0.0,
            timestamp TEXT NOT NULL,
            request_id TEXT
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_provider ON api_usage(provider)
        ''');

        await db.execute('''
          CREATE INDEX idx_model ON api_usage(model)
        ''');

        await db.execute('''
          CREATE INDEX idx_timestamp ON api_usage(timestamp)
        ''');
      },
    );
  }

  Future<void> recordUsage({
    required String provider,
    required String model,
    required int promptTokens,
    required int completionTokens,
    String? requestId,
  }) async {
    final totalTokens = promptTokens + completionTokens;
    final cost = _calculateCost(model, promptTokens, completionTokens);

    final record = APIUsageRecord(
      id: const Uuid().v4(),
      provider: provider,
      model: model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      cost: cost,
      timestamp: DateTime.now(),
      requestId: requestId,
    );

    final db = await database;
    await db.insert('api_usage', record.toMap());
    _recordController.add(record);
  }

  double _calculateCost(String model, int promptTokens, int completionTokens) {
    final pricePer1k = _modelPricing[model] ?? 0.002;
    return ((promptTokens + completionTokens) / 1000) * pricePer1k;
  }

  void setModelPricing(String model, double pricePer1kTokens) {
    _modelPricing[model] = pricePer1kTokens;
  }

  Future<CostSummary> getSummary({Duration? period}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (period != null) {
      final cutoff = DateTime.now().subtract(period);
      whereClause = 'timestamp >= ?';
      whereArgs = [cutoff.toIso8601String()];
    }

    final results = await db.query(
      'api_usage',
      where: whereClause,
      whereArgs: whereArgs,
    );

    double totalCost = 0;
    int totalTokens = 0;
    final costByProvider = <String, double>{};
    final costByModel = <String, double>{};
    final tokensByProvider = <String, int>{};

    for (final map in results) {
      final record = APIUsageRecord.fromMap(map);
      totalCost += record.cost;
      totalTokens += record.totalTokens;

      costByProvider[record.provider] =
          (costByProvider[record.provider] ?? 0) + record.cost;
      costByModel[record.model] =
          (costByModel[record.model] ?? 0) + record.cost;
      tokensByProvider[record.provider] =
          (tokensByProvider[record.provider] ?? 0) + record.totalTokens;
    }

    return CostSummary(
      totalCost: totalCost,
      totalTokens: totalTokens,
      totalRequests: results.length,
      costByProvider: costByProvider,
      costByModel: costByModel,
      tokensByProvider: tokensByProvider,
    );
  }

  Future<CostSummary> getTodaySummary() async {
    return getSummary(period: const Duration(days: 1));
  }

  Future<CostSummary> getWeekSummary() async {
    return getSummary(period: const Duration(days: 7));
  }

  Future<CostSummary> getMonthSummary() async {
    return getSummary(period: const Duration(days: 30));
  }

  Future<List<APIUsageRecord>> getRecentRecords({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'api_usage',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((map) => APIUsageRecord.fromMap(map)).toList();
  }

  Future<Map<String, double>> getDailyCosts({int days = 7}) async {
    final db = await database;
    final dailyCosts = <String, double>{};
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyCosts[dateKey] = 0;
    }

    final results = await db.query('api_usage');
    for (final map in results) {
      final record = APIUsageRecord.fromMap(map);
      final dateKey = '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
      if (dailyCosts.containsKey(dateKey)) {
        dailyCosts[dateKey] = dailyCosts[dateKey]! + record.cost;
      }
    }

    return dailyCosts;
  }

  Future<Map<String, int>> getDailyTokens({int days = 7}) async {
    final db = await database;
    final dailyTokens = <String, int>{};
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyTokens[dateKey] = 0;
    }

    final results = await db.query('api_usage');
    for (final map in results) {
      final record = APIUsageRecord.fromMap(map);
      final dateKey = '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
      if (dailyTokens.containsKey(dateKey)) {
        dailyTokens[dateKey] = dailyTokens[dateKey]! + record.totalTokens;
      }
    }

    return dailyTokens;
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('api_usage');
  }

  void dispose() {
    _recordController.close();
  }
}
