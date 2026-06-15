import 'dart:async';
import '../models/memory_record.dart';
import '../models/activity_event.dart';
import '../repositories/memory_repository.dart';
import '../memory_system.dart';
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

class MemoryRepositoryAdapter implements MemoryRepository {
  final MemorySystem _system;
  final _controller = StreamController<List<MemoryRecord>>.broadcast();

  MemoryRepositoryAdapter(this._system) {
    _system.memoryStream.listen((_) => _notifyListeners());
    _notifyListeners();
  }

  MemoryRecord _adapt(MemoryEntry e) {
    final type = MemoryType.values.firstWhere(
      (t) => t.name == e.category,
      orElse: () => MemoryType.fact,
    );
    return MemoryRecord(
      id: e.id,
      type: type,
      content: e.content,
      tags: [],
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      source: 'memory',
      importance: e.metadata['importance'] as int? ?? 5,
      metadata: e.metadata,
    );
  }

  @override
  Future<void> save(MemoryRecord record) async {}

  @override
  Future<void> saveAll(List<MemoryRecord> records) async {}

  @override
  Future<MemoryRecord?> getById(String id) async {
    final all = await _system.getAllMemories();
    try {
      return _adapt(all.firstWhere((e) => e.id == id));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MemoryRecord>> getAll() async {
    final entries = await _system.getAllMemories();
    return entries.map(_adapt).toList();
  }

  @override
  Future<List<MemoryRecord>> getByType(MemoryType type) async {
    final entries = await _system.getAllMemories();
    return entries.where((e) => e.category == type.name).map(_adapt).toList();
  }

  @override
  Future<List<MemoryRecord>> search(String query) async {
    final entries = await _system.searchMemory(query);
    return entries.map(_adapt).toList();
  }

  @override
  Future<List<MemoryRecord>> getRecent({int limit = 50}) async {
    final entries = await _system.getAllMemories();
    return entries.take(limit).map(_adapt).toList();
  }

  @override
  Future<int> count() async {
    final entries = await _system.getAllMemories();
    return entries.length;
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<List<MemoryRecord>> watchAll() => _controller.stream;

  void _notifyListeners() async {
    final all = await getAll();
    _controller.add(all);
  }

  void dispose() {
    _controller.close();
  }
}
