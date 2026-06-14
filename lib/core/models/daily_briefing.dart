class DailyBriefing {
  final DateTime date;
  final String greeting;
  final String summary;
  final List<BriefingItem> items;
  final BriefingStats stats;
  final DateTime generatedAt;

  const DailyBriefing({
    required this.date,
    required this.greeting,
    required this.summary,
    required this.items,
    required this.stats,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'greeting': greeting,
      'summary': summary,
      'items': items.map((e) => e.toMap()).toList(),
      'stats': stats.toMap(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

class BriefingItem {
  final String icon;
  final String title;
  final String description;
  final BriefingItemType type;

  const BriefingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'title': title,
      'description': description,
      'type': type.name,
    };
  }
}

enum BriefingItemType {
  agentActivity,
  memoryUpdate,
  automationEvent,
  calendarEvent,
  systemEvent,
}

class BriefingStats {
  final int totalMemories;
  final int activeAgents;
  final int completedTasks;
  final int pendingTasks;
  final int automationsRunning;
  final String dominantMood;

  const BriefingStats({
    required this.totalMemories,
    required this.activeAgents,
    required this.completedTasks,
    required this.pendingTasks,
    required this.automationsRunning,
    required this.dominantMood,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalMemories': totalMemories,
      'activeAgents': activeAgents,
      'completedTasks': completedTasks,
      'pendingTasks': pendingTasks,
      'automationsRunning': automationsRunning,
      'dominantMood': dominantMood,
    };
  }
}
