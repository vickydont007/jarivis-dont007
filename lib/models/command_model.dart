class JarvisCommand {
  final String id;
  final String action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final bool isResponse;
  final String? status;
  final dynamic result;
  final String? error;

  JarvisCommand({
    required this.id,
    required this.action,
    this.payload = const {},
    DateTime? createdAt,
    this.isResponse = false,
    this.status,
    this.result,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': isResponse ? 'result' : 'command',
    'id': id,
    'action': action,
    'payload': payload,
    'timestamp': createdAt.toIso8601String(),
    if (isResponse) 'status': status,
    if (isResponse) 'result': result,
    if (isResponse) 'error': error,
  };

  factory JarvisCommand.fromJson(Map<String, dynamic> json) {
    final isResponse = json['type'] == 'result';
    return JarvisCommand(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      createdAt: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      isResponse: isResponse,
      status: json['status'] as String?,
      result: json['result'],
      error: json['error'] as String?,
    );
  }

  JarvisCommand successResponse(dynamic data) => JarvisCommand(
    id: id,
    action: action,
    isResponse: true,
    status: 'success',
    result: data,
  );

  JarvisCommand errorResponse(String errorMessage) => JarvisCommand(
    id: id,
    action: action,
    isResponse: true,
    status: 'error',
    error: errorMessage,
  );
}
