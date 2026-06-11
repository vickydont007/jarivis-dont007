class SystemInfo {
  final double cpuUsage;       // 0.0 - 1.0
  final double memoryUsage;    // 0.0 - 1.0
  final int memoryTotalMB;
  final int memoryUsedMB;
  final int diskTotalGB;
  final int diskUsedGB;
  final double diskUsage;      // 0.0 - 1.0
  final int uptimeHours;
  final String osVersion;
  final String hostname;
  final DateTime timestamp;

  SystemInfo({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.memoryTotalMB,
    required this.memoryUsedMB,
    required this.diskTotalGB,
    required this.diskUsedGB,
    required this.diskUsage,
    required this.uptimeHours,
    required this.osVersion,
    required this.hostname,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get cpuPercent => (cpuUsage * 100).roundToDouble();
  double get memoryPercent => (memoryUsage * 100).roundToDouble();
  double get diskPercent => (diskUsage * 100).roundToDouble();

  Map<String, dynamic> toJson() => {
    'cpuUsage': cpuUsage,
    'memoryUsage': memoryUsage,
    'memoryTotalMB': memoryTotalMB,
    'memoryUsedMB': memoryUsedMB,
    'diskTotalGB': diskTotalGB,
    'diskUsedGB': diskUsedGB,
    'diskUsage': diskUsage,
    'uptimeHours': uptimeHours,
    'osVersion': osVersion,
    'hostname': hostname,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SystemInfo.fromJson(Map<String, dynamic> json) => SystemInfo(
    cpuUsage: (json['cpuUsage'] as num).toDouble(),
    memoryUsage: (json['memoryUsage'] as num).toDouble(),
    memoryTotalMB: json['memoryTotalMB'] as int,
    memoryUsedMB: json['memoryUsedMB'] as int,
    diskTotalGB: json['diskTotalGB'] as int,
    diskUsedGB: json['diskUsedGB'] as int,
    diskUsage: (json['diskUsage'] as num).toDouble(),
    uptimeHours: json['uptimeHours'] as int,
    osVersion: json['osVersion'] as String,
    hostname: json['hostname'] as String,
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : null,
  );
}
