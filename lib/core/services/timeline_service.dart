import 'dart:async';
import '../models/activity_event.dart';
import '../repositories/timeline_repository.dart';

class TimelineService {
  final TimelineRepository _repository;
  final StreamController<ActivityEvent> _eventController =
      StreamController<ActivityEvent>.broadcast();

  TimelineService({TimelineRepository? repository})
      : _repository = repository ?? InMemoryTimelineRepository();

  Stream<ActivityEvent> get eventStream => _eventController.stream;

  Future<ActivityEvent> log({
    required String source,
    required ActivityType type,
    required String title,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    final event = ActivityEvent.create(
      source: source,
      type: type,
      title: title,
      description: description,
      metadata: metadata,
    );
    await _repository.save(event);
    _eventController.add(event);
    return event;
  }

  Future<List<ActivityEvent>> getRecent({int limit = 50}) {
    return _repository.getRecent(limit: limit);
  }

  Future<List<ActivityEvent>> getByType(ActivityType type, {int limit = 50}) {
    return _repository.getByType(type, limit: limit);
  }

  Future<List<ActivityEvent>> getBySource(String source, {int limit = 50}) {
    return _repository.getBySource(source, limit: limit);
  }

  Future<List<ActivityEvent>> getSince(DateTime since) {
    return _repository.getSince(since);
  }

  Future<List<ActivityEvent>> getTodayEvents() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return _repository.getSince(startOfDay);
  }

  Future<List<ActivityEvent>> getThisWeekEvents() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _repository.getSince(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day));
  }

  Future<int> count() => _repository.count();

  Future<void> clear() => _repository.clear();

  void dispose() {
    _eventController.close();
  }
}
