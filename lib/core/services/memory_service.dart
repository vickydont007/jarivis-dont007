import 'dart:async';
import '../models/memory_record.dart';
import '../models/activity_event.dart';
import '../repositories/memory_repository.dart';
import 'timeline_service.dart';

class MemoryService {
  final MemoryRepository _repository;
  final TimelineService _timeline;
  final StreamController<MemoryRecord> _memoryUpdateController =
      StreamController<MemoryRecord>.broadcast();

  MemoryService({
    MemoryRepository? repository,
    required TimelineService timeline,
  })  : _repository = repository ?? InMemoryMemoryRepository(),
        _timeline = timeline;

  Stream<MemoryRecord> get memoryUpdates => _memoryUpdateController.stream;

  Future<MemoryRecord> addMemory({
    required MemoryType type,
    required String content,
    List<String> tags = const [],
    required String source,
    int importance = 5,
    Map<String, dynamic> metadata = const {},
  }) async {
    final record = MemoryRecord.create(
      type: type,
      content: content,
      tags: tags,
      source: source,
      importance: importance,
      metadata: metadata,
    );
    await _repository.save(record);
    await _timeline.log(
      source: 'Memory',
      type: ActivityType.memoryCreated,
      title: 'Memory Created',
      description: content.length > 50 ? '${content.substring(0, 50)}...' : content,
      metadata: {'memoryId': record.id, 'type': type.name},
    );
    _memoryUpdateController.add(record);
    return record;
  }

  Future<void> updateMemory({
    required String id,
    String? content,
    List<String>? tags,
    int? importance,
  }) async {
    final existing = await _repository.getById(id);
    if (existing == null) return;

    final updated = existing.copyWith(
      content: content,
      tags: tags,
      importance: importance,
    );
    await _repository.save(updated);
    await _timeline.log(
      source: 'Memory',
      type: ActivityType.memoryUpdated,
      title: 'Memory Updated',
      description: 'Memory updated: ${existing.typeLabel}',
      metadata: {'memoryId': id},
    );
    _memoryUpdateController.add(updated);
  }

  Future<void> deleteMemory(String id) async {
    final existing = await _repository.getById(id);
    if (existing == null) return;

    await _repository.delete(id);
    await _timeline.log(
      source: 'Memory',
      type: ActivityType.memoryDeleted,
      title: 'Memory Deleted',
      description: 'Deleted: ${existing.content}',
      metadata: {'memoryId': id},
    );
  }

  Future<List<MemoryRecord>> searchMemory(String query) {
    return _repository.search(query);
  }

  Future<List<MemoryRecord>> recentMemories({int limit = 50}) {
    return _repository.getRecent(limit: limit);
  }

  Future<List<MemoryRecord>> getByType(MemoryType type) {
    return _repository.getByType(type);
  }

  Future<List<MemoryRecord>> getAll() => _repository.getAll();

  Future<int> count() => _repository.count();

  Stream<List<MemoryRecord>> watchMemories() => _repository.watchAll();

  void dispose() {
    _memoryUpdateController.close();
  }
}
