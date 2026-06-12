import 'dart:async';

enum MessageType {
  task,
  result,
  request,
  response,
  broadcast,
  heartbeat,
}

class AgentMessage {
  final String id;
  final String fromId;
  final String toId;
  final MessageType type;
  final String content;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final String? taskId;
  final String? replyToId;

  AgentMessage({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.type,
    required this.content,
    this.payload = const {},
    required this.timestamp,
    this.taskId,
    this.replyToId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from_id': fromId,
    'to_id': toId,
    'type': type.name,
    'content': content,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'task_id': taskId,
    'reply_to_id': replyToId,
  };

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    return AgentMessage(
      id: json['id'],
      fromId: json['from_id'],
      toId: json['to_id'],
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.task,
      ),
      content: json['content'],
      payload: json['payload'] ?? {},
      timestamp: DateTime.parse(json['timestamp']),
      taskId: json['task_id'],
      replyToId: json['reply_to_id'],
    );
  }
}

class MessageChannel {
  final String id;
  final String name;
  final List<String> participants;
  final StreamController<AgentMessage> _controller =
      StreamController<AgentMessage>.broadcast();
  final List<AgentMessage> _messages = [];

  MessageChannel({
    required this.id,
    required this.name,
    required this.participants,
  });

  Stream<AgentMessage> get stream => _controller.stream;
  List<AgentMessage> get messages => List.unmodifiable(_messages);

  void addMessage(AgentMessage message) {
    _messages.add(message);
    _controller.add(message);
  }

  void dispose() {
    _controller.close();
  }
}

class AgentCommunication {
  final Map<String, MessageChannel> _channels = {};
  final Map<String, List<String>> _agentInboxes = {};
  final StreamController<AgentMessage> _globalController =
      StreamController<AgentMessage>.broadcast();
  final StreamController<AgentMessage> _messageController =
      StreamController<AgentMessage>.broadcast();

  Stream<AgentMessage> get globalStream => _globalController.stream;
  Stream<AgentMessage> get messageStream => _messageController.stream;

  void registerAgent(String agentId) {
    _agentInboxes.putIfAbsent(agentId, () => []);
  }

  void unregisterAgent(String agentId) {
    _agentInboxes.remove(agentId);
    for (final channel in _channels.values) {
      channel.participants.remove(agentId);
    }
  }

  String createChannel(String name, List<String> participants) {
    final id = 'channel_${DateTime.now().millisecondsSinceEpoch}';
    _channels[id] = MessageChannel(
      id: id,
      name: name,
      participants: participants,
    );
    return id;
  }

  void joinChannel(String channelId, String agentId) {
    _channels[channelId]?.participants.add(agentId);
  }

  void leaveChannel(String channelId, String agentId) {
    _channels[channelId]?.participants.remove(agentId);
  }

  void sendMessage(AgentMessage message) {
    _messageController.add(message);
    _globalController.add(message);

    if (_agentInboxes.containsKey(message.toId)) {
      _agentInboxes[message.toId]!.add(message.content);
    }

    for (final channel in _channels.values) {
      if (channel.participants.contains(message.fromId) &&
          channel.participants.contains(message.toId)) {
        channel.addMessage(message);
      }
    }
  }

  void broadcastMessage(String fromId, String content, {Map<String, dynamic> payload = const {}}) {
    for (final agentId in _agentInboxes.keys) {
      if (agentId != fromId) {
        final message = AgentMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_$agentId',
          fromId: fromId,
          toId: agentId,
          type: MessageType.broadcast,
          content: content,
          payload: payload,
          timestamp: DateTime.now(),
        );
        sendMessage(message);
      }
    }
  }

  List<String> getInbox(String agentId) {
    return _agentInboxes[agentId] ?? [];
  }

  void clearInbox(String agentId) {
    _agentInboxes[agentId]?.clear();
  }

  List<AgentMessage> getChannelMessages(String channelId) {
    return _channels[channelId]?.messages ?? [];
  }

  List<String> getAgentChannels(String agentId) {
    return _channels.values
        .where((c) => c.participants.contains(agentId))
        .map((c) => c.id)
        .toList();
  }

  Map<String, dynamic> getStats() {
    return {
      'total_channels': _channels.length,
      'total_agents': _agentInboxes.length,
      'messages_per_channel': _channels.map((k, v) => MapEntry(k, v.messages.length)),
    };
  }

  void dispose() {
    _globalController.close();
    _messageController.close();
    for (final channel in _channels.values) {
      channel.dispose();
    }
  }
}
