import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final List<String>? imageUrls;
  final bool isStopped;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.imageUrls,
    this.isStopped = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'imageUrls': imageUrls,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      imageUrls: map['imageUrls'] != null ? List<String>.from(map['imageUrls']) : null,
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final List<Map<String, dynamic>> history;
  final bool isLoading;
  final CancelToken? cancelToken;

  ChatState({
    this.messages = const [],
    this.history = const [],
    this.isLoading = false,
    this.cancelToken,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<Map<String, dynamic>>? history,
    bool? isLoading,
    CancelToken? cancelToken,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState()) {
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    state = state.copyWith(
      messages: [
        ChatMessage(
          role: 'assistant',
          content: 'Hello! I am **Nextron**, your AI desktop assistant.\n\nI can help you with:\n- System control (shutdown, restart, sleep)\n- File management (read, write, search)\n- Web browsing and search\n- Code execution (Python/JS)\n- Image analysis\n- And much more!\n\nHow can I help you today?',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void addUserMessage(String content) {
    final token = CancelToken();
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          role: 'user',
          content: content,
          timestamp: DateTime.now(),
        ),
      ],
      history: [
        ...state.history,
        {'role': 'user', 'content': content},
      ],
      isLoading: true,
      cancelToken: token,
    );
  }

  void addAssistantMessage(String content, {List<String>? imageUrls}) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          role: 'assistant',
          content: content,
          timestamp: DateTime.now(),
          imageUrls: imageUrls,
        ),
      ],
      history: [
        ...state.history,
        {'role': 'assistant', 'content': content},
      ],
      isLoading: false,
      cancelToken: null,
    );
  }

  void addStoppedMessage() {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          role: 'assistant',
          content: '*[Response stopped by user]*',
          timestamp: DateTime.now(),
          isStopped: true,
        ),
      ],
      isLoading: false,
      cancelToken: null,
    );
  }

  void setLoading(bool loading) {
    if (!loading) {
      state = state.copyWith(isLoading: loading, cancelToken: null);
    } else {
      state = state.copyWith(isLoading: loading);
    }
  }

  void stopMessage() {
    final token = state.cancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('User stopped the request');
    }
    addStoppedMessage();
  }

  void clearMessages() {
    if (state.cancelToken != null && !state.cancelToken!.isCancelled) {
      state.cancelToken!.cancel('Chat cleared');
    }
    state = ChatState();
    _addWelcomeMessage();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
