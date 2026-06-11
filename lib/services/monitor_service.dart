import 'dart:async';
import '../core/logger.dart';
import '../models/system_info_model.dart';
import 'system_service.dart';

class MonitorService {
  static final MonitorService _instance = MonitorService._internal();
  factory MonitorService() => _instance;
  MonitorService._internal();

  final JarvisLogger _log = JarvisLogger();
  final SystemService _systemService = SystemService();
  
  Timer? _monitorTimer;
  SystemInfo? _lastInfo;
  
  final StreamController<SystemInfo> _infoController =
      StreamController<SystemInfo>.broadcast();
  final StreamController<MonitorAlert> _alertController =
      StreamController<MonitorAlert>.broadcast();

  Stream<SystemInfo> get onInfo => _infoController.stream;
  Stream<MonitorAlert> get onAlert => _alertController.stream;
  SystemInfo? get lastInfo => _lastInfo;

  // Thresholds for alerts
  double _cpuAlertThreshold = 0.9;    // 90%
  double _memoryAlertThreshold = 0.9; // 90%
  double _diskAlertThreshold = 0.95;  // 95%

  void setThresholds({
    double? cpu,
    double? memory,
    double? disk,
  }) {
    if (cpu != null) _cpuAlertThreshold = cpu;
    if (memory != null) _memoryAlertThreshold = memory;
    if (disk != null) _diskAlertThreshold = disk;
  }

  Future<void> start({int intervalSeconds = 5}) async {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        await _collectMetrics();
      },
    );
    // First immediate collection
    await _collectMetrics();
    _log.info('Monitor started (interval: ${intervalSeconds}s)');
  }

  Future<void> _collectMetrics() async {
    try {
      final info = await _systemService.getInfo();
      _lastInfo = info;
      _infoController.add(info);

      // Check thresholds
      if (info.cpuUsage >= _cpuAlertThreshold) {
        _alertController.add(MonitorAlert(
          type: AlertType.cpu,
          message: 'CPU usage at ${(info.cpuPercent).toStringAsFixed(1)}%',
          value: info.cpuUsage,
          threshold: _cpuAlertThreshold,
          timestamp: info.timestamp,
        ));
      }
      if (info.memoryUsage >= _memoryAlertThreshold) {
        _alertController.add(MonitorAlert(
          type: AlertType.memory,
          message: 'Memory usage at ${(info.memoryPercent).toStringAsFixed(1)}%',
          value: info.memoryUsage,
          threshold: _memoryAlertThreshold,
          timestamp: info.timestamp,
        ));
      }
      if (info.diskUsage >= _diskAlertThreshold) {
        _alertController.add(MonitorAlert(
          type: AlertType.disk,
          message: 'Disk usage at ${(info.diskPercent).toStringAsFixed(1)}%',
          value: info.diskUsage,
          threshold: _diskAlertThreshold,
          timestamp: info.timestamp,
        ));
      }
    } catch (e) {
      _log.error('Monitor collection failed', exception: e);
    }
  }

  void stop() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _log.info('Monitor stopped');
  }

  void dispose() {
    stop();
    _infoController.close();
    _alertController.close();
  }
}

enum AlertType { cpu, memory, disk }

class MonitorAlert {
  final AlertType type;
  final String message;
  final double value;
  final double threshold;
  final DateTime timestamp;

  MonitorAlert({
    required this.type,
    required this.message,
    required this.value,
    required this.threshold,
    required this.timestamp,
  });
}
