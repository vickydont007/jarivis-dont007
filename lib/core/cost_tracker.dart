import 'dart:async';

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

  Map<String, dynamic> toJson() => {
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

  factory APIUsageRecord.fromJson(Map<String, dynamic> json) {
    return APIUsageRecord(
      id: json['id'],
      provider: json['provider'],
      model: json['model'],
      promptTokens: json['prompt_tokens'] ?? 0,
      completionTokens: json['completion_tokens'] ?? 0,
      totalTokens: json['total_tokens'] ?? 0,
      cost: (json['cost'] ?? 0).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      requestId: json['request_id'],
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

  Map<String, dynamic> toJson() => {
    'total_cost': totalCost,
    'total_tokens': totalTokens,
    'total_requests': totalRequests,
    'cost_by_provider': costByProvider,
    'cost_by_model': costByModel,
    'tokens_by_provider': tokensByProvider,
  };
}

class CostTracker {
  final List<APIUsageRecord> _records = [];
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
  List<APIUsageRecord> get records => List.unmodifiable(_records);

  void recordUsage({
    required String provider,
    required String model,
    required int promptTokens,
    required int completionTokens,
    String? requestId,
  }) {
    final totalTokens = promptTokens + completionTokens;
    final cost = _calculateCost(model, promptTokens, completionTokens);

    final record = APIUsageRecord(
      id: 'usage_${DateTime.now().millisecondsSinceEpoch}',
      provider: provider,
      model: model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      cost: cost,
      timestamp: DateTime.now(),
      requestId: requestId,
    );

    _records.add(record);
    _recordController.add(record);
  }

  double _calculateCost(String model, int promptTokens, int completionTokens) {
    final pricePer1k = _modelPricing[model] ?? 0.002;
    return ((promptTokens + completionTokens) / 1000) * pricePer1k;
  }

  void setModelPricing(String model, double pricePer1kTokens) {
    _modelPricing[model] = pricePer1kTokens;
  }

  CostSummary getSummary({Duration? period}) {
    final cutoff = period != null
        ? DateTime.now().subtract(period)
        : DateTime(2020);

    final filteredRecords = _records
        .where((r) => r.timestamp.isAfter(cutoff))
        .toList();

    double totalCost = 0;
    int totalTokens = 0;
    final costByProvider = <String, double>{};
    final costByModel = <String, double>{};
    final tokensByProvider = <String, int>{};

    for (final record in filteredRecords) {
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
      totalRequests: filteredRecords.length,
      costByProvider: costByProvider,
      costByModel: costByModel,
      tokensByProvider: tokensByProvider,
    );
  }

  CostSummary getTodaySummary() {
    return getSummary(period: const Duration(days: 1));
  }

  CostSummary getWeekSummary() {
    return getSummary(period: const Duration(days: 7));
  }

  CostSummary getMonthSummary() {
    return getSummary(period: const Duration(days: 30));
  }

  List<APIUsageRecord> getRecentRecords({int limit = 20}) {
    final sorted = List<APIUsageRecord>.from(_records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  Map<String, double> getDailyCosts({int days = 7}) {
    final dailyCosts = <String, double>{};
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyCosts[dateKey] = 0;
    }

    for (final record in _records) {
      final dateKey = '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
      if (dailyCosts.containsKey(dateKey)) {
        dailyCosts[dateKey] = dailyCosts[dateKey]! + record.cost;
      }
    }

    return dailyCosts;
  }

  Map<String, int> getDailyTokens({int days = 7}) {
    final dailyTokens = <String, int>{};
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyTokens[dateKey] = 0;
    }

    for (final record in _records) {
      final dateKey = '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
      if (dailyTokens.containsKey(dateKey)) {
        dailyTokens[dateKey] = dailyTokens[dateKey]! + record.totalTokens;
      }
    }

    return dailyTokens;
  }

  void clear() {
    _records.clear();
  }

  void dispose() {
    _recordController.close();
  }
}
