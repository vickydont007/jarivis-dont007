import 'package:flutter_test/flutter_test.dart';
import 'package:nextron_ai/core/models/consolidated_memory.dart';

void main() {
  group('ConsolidatedMemory', () {
    test('creates with correct defaults', () {
      final memory = ConsolidatedMemory.create(
        content: 'User name is Rahul',
        category: MemoryCategory.name,
      );

      expect(memory.content, 'User name is Rahul');
      expect(memory.category, MemoryCategory.name);
      expect(memory.importanceScore, 50);
      expect(memory.confidenceScore, 0.5);
      expect(memory.source, 'conversation');
      expect(memory.id.startsWith('cm_'), true);
    });

    test('serializes to/from map', () {
      final original = ConsolidatedMemory.create(
        content: 'Building Nextron AI',
        category: MemoryCategory.project,
        importanceScore: 80,
        confidenceScore: 0.7,
        source: 'user_message',
      );

      final map = original.toMap();
      final restored = ConsolidatedMemory.fromMap(map);

      expect(restored.content, original.content);
      expect(restored.category, original.category);
      expect(restored.importanceScore, original.importanceScore);
      expect(restored.confidenceScore, original.confidenceScore);
      expect(restored.source, original.source);
    });

    test('effectiveScore calculates correctly', () {
      final memory = ConsolidatedMemory.create(
        content: 'test',
        category: MemoryCategory.fact,
        importanceScore: 80,
        confidenceScore: 0.75,
      );

      expect(memory.effectiveScore, 60.0); // 80 * 0.75
    });

    test('isHighValue detects important memories', () {
      final highValue = ConsolidatedMemory.create(
        content: 'User name',
        category: MemoryCategory.name,
        importanceScore: 80,
        confidenceScore: 0.8,
      );

      final lowValue = ConsolidatedMemory.create(
        content: 'Small talk',
        category: MemoryCategory.daily,
        importanceScore: 30,
        confidenceScore: 0.3,
      );

      expect(highValue.isHighValue, true);
      expect(lowValue.isHighValue, false);
    });

    test('needsReinforcement detects under-confident memories', () {
      final needsReinforcement = ConsolidatedMemory.create(
        content: 'New fact',
        category: MemoryCategory.fact,
        importanceScore: 50,
        confidenceScore: 0.4,
      );
      // reinforcementCount defaults to 1, confidence < 0.7
      expect(needsReinforcement.needsReinforcement, true);

      final wellEstablished = ConsolidatedMemory.create(
        content: 'Well known fact',
        category: MemoryCategory.fact,
        importanceScore: 80,
        confidenceScore: 0.9,
      );
      // reinforcementCount defaults to 1 but confidence >= 0.7
      expect(wellEstablished.needsReinforcement, false);
    });

    test('MemoryCategory enum covers all required types', () {
      expect(MemoryCategory.values, contains(MemoryCategory.name));
      expect(MemoryCategory.values, contains(MemoryCategory.project));
      expect(MemoryCategory.values, contains(MemoryCategory.goal));
      expect(MemoryCategory.values, contains(MemoryCategory.skill));
      expect(MemoryCategory.values, contains(MemoryCategory.interest));
      expect(MemoryCategory.values, contains(MemoryCategory.preference));
      expect(MemoryCategory.values, contains(MemoryCategory.relationship));
      expect(MemoryCategory.values, contains(MemoryCategory.date));
      expect(MemoryCategory.values, contains(MemoryCategory.plan));
      expect(MemoryCategory.values, contains(MemoryCategory.fact));
      expect(MemoryCategory.values, contains(MemoryCategory.emotional));
      expect(MemoryCategory.values, contains(MemoryCategory.daily));
    });
  });

  group('UserProfile', () {
    test('creates and serializes correctly', () {
      final profile = UserProfile(
        id: 'up_123',
        fieldName: 'name',
        fieldValue: 'Rahul',
        confidence: 0.9,
        source: 'conversation',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      final map = profile.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.fieldName, 'name');
      expect(restored.fieldValue, 'Rahul');
      expect(restored.confidence, 0.9);
    });
  });

  group('MemoryLink', () {
    test('creates and serializes correctly', () {
      final link = MemoryLink(
        id: 'ml_123',
        fromMemoryId: 'cm_1',
        toMemoryId: 'cm_2',
        relationship: 'related_to',
        strength: 0.8,
        createdAt: DateTime(2025),
      );

      final map = link.toMap();
      final restored = MemoryLink.fromMap(map);

      expect(restored.relationship, 'related_to');
      expect(restored.strength, 0.8);
    });
  });
}
