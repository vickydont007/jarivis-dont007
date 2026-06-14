import 'dart:async';
import '../models/activity_event.dart';

abstract class TimelineRepository {
  Future<void> save(ActivityEvent event);
  Future<void> saveAll(List<ActivityEvent> events);
  Future<List<ActivityEvent>> getRecent({int limit = 50});
  Future<List<ActivityEvent>> getByType(ActivityType type, {int limit = 50});
  Future<List<ActivityEvent>> getBySource(String source, {int limit = 50});
  Future<List<ActivityEvent>> getSince(DateTime since);
  Future<int> count();
  Future<void> delete(String id);
  Future<void> clear();
  Stream<List<ActivityEvent>> watchRecent({int limit = 50});
}

class InMemoryTimelineRepository implements TimelineRepository {
  final List<ActivityEvent> _events = [];
  final StreamController<List<ActivityEvent>> _controller =
      StreamController<List<ActivityEvent>>.broadcast();

  @override
  Future<void> save(ActivityEvent event) async {
    _events.insert(0, event);
    if (_events.length > 1000) {
      _events.removeRange(1000, _events.length);
    }
    _notifyListeners();
  }

  @override
  Future<void> saveAll(List<ActivityEvent> events) async {
    _events.insertAll(0, events);
    if (_events.length > 1000) {
      _events.removeRange(1000, _events.length);
    }
    _notifyListeners();
  }

  @override
  Future<List<ActivityEvent>> getRecent({int limit = 50}) async {
    return _events.take(limit).toList();
  }

  @override
  Future<List<ActivityEvent>> getByType(ActivityType type,
      {int limit = 50}) async {
    return _events.where((e) => e.type == type).take(limit).toList();
  }

  @override
  Future<List<ActivityEvent>> getBySource(String source,
      {int limit = 50}) async {
    return _events.where((e) => e.source == source).take(limit).toList();
  }

  @override
  Future<List<ActivityEvent>> getSince(DateTime since) async {
    return _events.where((e) => e.timestamp.isAfter(since)).toList();
  }

  @override
  Future<int> count() async => _events.length;

  @override
  Future<void> delete(String id) async {
    _events.removeWhere((e) => e.id == id);
    _notifyListeners();
  }

  @override
  Future<void> clear() async {
    _events.clear();
    _notifyListeners();
  }

  @override
  Stream<List<ActivityEvent>> watchRecent({int limit = 50}) {
    return _controller.stream.map((events) => events.take(limit).toList());
  }

  void _notifyListeners() {
    _controller.add(List.unmodifiable(_events));
  }

  void dispose() {
    _controller.close();
  }
}
