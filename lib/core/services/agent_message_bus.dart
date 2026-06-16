import 'dart:async';
import '../models/workflow.dart';

class WorkflowMessage {
  final String id;
  final String workflowId;
  final WorkflowMessageType type;
  final String? taskId;
  final String? agentType;
  final dynamic data;
  final DateTime timestamp;

  WorkflowMessage({
    required this.id,
    required this.workflowId,
    required this.type,
    this.taskId,
    this.agentType,
    this.data,
    required this.timestamp,
  });
}

class AgentMessageBus {
  final StreamController<WorkflowMessage> _controller = StreamController<WorkflowMessage>.broadcast();
  final Map<String, List<WorkflowMessage>> _messageHistory = {};
  final Map<String, List<Function(WorkflowMessage)>> _subscribers = {};

  Stream<WorkflowMessage> get messageStream => _controller.stream;

  void publish(WorkflowMessage message) {
    _controller.add(message);
    _messageHistory.putIfAbsent(message.workflowId, () => []).add(message);
    _notifySubscribers(message);
  }

  void subscribe(String workflowId, Function(WorkflowMessage) callback) {
    _subscribers.putIfAbsent(workflowId, () => []).add(callback);
  }

  void unsubscribe(String workflowId) {
    _subscribers.remove(workflowId);
  }

  void _notifySubscribers(WorkflowMessage message) {
    final subs = _subscribers[message.workflowId];
    if (subs != null) {
      for (final callback in subs) {
        try {
          callback(message);
        } catch (_) {}
      }
    }
  }

  List<WorkflowMessage> getHistory(String workflowId) {
    return _messageHistory[workflowId] ?? [];
  }

  void dispose() {
    _controller.close();
    _subscribers.clear();
    _messageHistory.clear();
  }
}
