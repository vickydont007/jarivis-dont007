import 'dart:async';
import '../models/memory_record.dart';

abstract class MemoryRepository {
  Future<void> save(MemoryRecord record);
  Future<void> saveAll(List<MemoryRecord> records);
  Future<MemoryRecord?> getById(String id);
  Future<List<MemoryRecord>> getAll();
  Future<List<MemoryRecord>> getByType(MemoryType type);
  Future<List<MemoryRecord>> search(String query);
  Future<List<MemoryRecord>> getRecent({int limit = 50});
  Future<int> count();
  Future<void> delete(String id);
  Future<void> clear();
  Stream<List<MemoryRecord>> watchAll();
}

class InMemoryMemoryRepository implements MemoryRepository {
  final Map<String, MemoryRecord> _records = {};
  final StreamController<List<MemoryRecord>> _controller =
      StreamController<List<MemoryRecord>>.broadcast();

  @override
  Future<void> save(MemoryRecord record) async {
    _records[record.id] = record;
    _notifyListeners();
  }

  @override
  Future<void> saveAll(List<MemoryRecord> records) async {
    for (final record in records) {
      _records[record.id] = record;
    }
    _notifyListeners();
  }

  @override
  Future<MemoryRecord?> getById(String id) async => _records[id];

  @override
  Future<List<MemoryRecord>> getAll() async =>
      _records.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<List<MemoryRecord>> getByType(MemoryType type) async {
    return _records.values.where((r) => r.type == type).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<List<MemoryRecord>> search(String query) async {
    final lowerQuery = query.toLowerCase();
    return _records.values.where((r) {
      return r.content.toLowerCase().contains(lowerQuery) ||
          r.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<List<MemoryRecord>> getRecent({int limit = 50}) async {
    final sorted = _records.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<int> count() async => _records.length;

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
    _notifyListeners();
  }

  @override
  Future<void> clear() async {
    _records.clear();
    _notifyListeners();
  }

  @override
  Stream<List<MemoryRecord>> watchAll() {
    return _controller.stream;
  }

  void _notifyListeners() {
    _controller.add(_records.values.toList());
  }

  void dispose() {
    _controller.close();
  }
}
