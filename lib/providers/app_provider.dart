import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ai_engine.dart';
import '../core/memory_system.dart';

class AppState {
  final AIEngine? aiEngine;
  final bool isConnected;
  final AIProvider provider;
  final String apiKey;
  final MemorySystem? memory;

  AppState({
    this.aiEngine,
    this.isConnected = false,
    this.provider = AIProvider.openrouter,
    this.apiKey = '',
    this.memory,
  });

  AppState copyWith({
    AIEngine? aiEngine,
    bool? isConnected,
    AIProvider? provider,
    String? apiKey,
    MemorySystem? memory,
  }) {
    return AppState(
      aiEngine: aiEngine ?? this.aiEngine,
      isConnected: isConnected ?? this.isConnected,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      memory: memory ?? this.memory,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AIEngine? _engine;
  MemorySystem? _memory;

  AppStateNotifier() : super(AppState()) {
    _memory = MemorySystem();
    state = state.copyWith(memory: _memory);
  }

  Future<void> initializeAI({
    required AIProvider provider,
    required String apiKey,
    String? baseUrl,
    String? modelName,
  }) async {
    _engine = AIEngine(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
    );

    try {
      await _engine!.connect();
      state = state.copyWith(
        aiEngine: _engine,
        isConnected: true,
        provider: provider,
        apiKey: apiKey,
      );
    } catch (e) {
      print('Failed to connect to AI: $e');
      state = state.copyWith(
        aiEngine: _engine,
        isConnected: false,
        provider: provider,
        apiKey: apiKey,
      );
    }
  }

  Future<String> sendMessage(String message, {List<Map<String, dynamic>>? history}) async {
    if (_engine == null) {
      return 'AI Engine not initialized. Please configure in Settings.';
    }

    try {
      // Save to memory
      final memoryEntry = MemoryEntry.create(
        content: message,
        category: 'chat',
        metadata: {'role': 'user'},
      );
      _memory?.addMemory(memoryEntry);

      final response = await _engine!.sendMessage(message, history: history);

      // Save response to memory
      final responseEntry = MemoryEntry.create(
        content: response,
        category: 'chat',
        metadata: {'role': 'assistant'},
      );
      _memory?.addMemory(responseEntry);

      return response;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Stream<String> sendMessageStream(String message, {List<Map<String, dynamic>>? history}) async* {
    if (_engine == null) {
      yield 'AI Engine not initialized. Please configure in Settings.';
      return;
    }
    
    // Save to memory
    final memoryEntry = MemoryEntry.create(
      content: message,
      category: 'chat',
      metadata: {'role': 'user'},
    );
    _memory?.addMemory(memoryEntry);

    yield* _engine!.sendMessageStream(message, history: history);
  }

  void disconnect() {
    _engine?.disconnect();
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    _engine?.dispose();
    _memory?.dispose();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
