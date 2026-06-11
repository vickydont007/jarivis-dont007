import 'dart:async';
import 'dart:collection';
import 'package:uuid/uuid.dart';

enum SecurityLevel {
  low,
  medium,
  high,
  critical,
}

enum ThreatType {
  injection,
  unauthorizedAccess,
  rateLimitExceeded,
  maliciousInput,
  dataLeak,
}

class SecurityEvent {
  final String id;
  final ThreatType type;
  final SecurityLevel level;
  final String description;
  final String source;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  SecurityEvent({
    required this.id,
    required this.type,
    required this.level,
    required this.description,
    required this.source,
    required this.metadata,
    required this.timestamp,
  });

  factory SecurityEvent.create({
    required ThreatType type,
    required SecurityLevel level,
    required String description,
    required String source,
    Map<String, dynamic> metadata = const {},
  }) {
    return SecurityEvent(
      id: const Uuid().v4(),
      type: type,
      level: level,
      description: description,
      source: source,
      metadata: metadata,
      timestamp: DateTime.now(),
    );
  }
}

class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _requests = Queue<DateTime>();

  RateLimiter({
    this.maxRequests = 100,
    this.window = const Duration(minutes: 1),
  });

  bool allow() {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Remove old requests
    while (_requests.isNotEmpty && _requests.first.isBefore(windowStart)) {
      _requests.removeFirst();
    }

    if (_requests.length >= maxRequests) {
      return false;
    }

    _requests.add(now);
    return true;
  }

  int get currentCount => _requests.length;
}

class Guardrails {
  final List<String> _blockedPatterns = [
    'ignore previous instructions',
    'ignore all previous',
    'disregard your instructions',
    'you are now',
    'act as',
    'pretend to be',
    'roleplay as',
    'jailbreak',
    'bypass',
  ];

  final List<String> _sensitiveDataPatterns = [
    r'\b\d{3}-\d{2}-\d{4}\b', // SSN
    r'\b\d{16}\b', // Credit card
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', // Email
    r'\b\d{10}\b', // Phone number
  ];

  // Check for prompt injection
  bool checkPromptInjection(String input) {
    final lowerInput = input.toLowerCase();
    for (final pattern in _blockedPatterns) {
      if (lowerInput.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  // Check for sensitive data
  bool containsSensitiveData(String input) {
    for (final pattern in _sensitiveDataPatterns) {
      if (RegExp(pattern).hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  // Sanitize input
  String sanitizeInput(String input) {
    String sanitized = input;

    // Remove potentially harmful characters
    sanitized = sanitized.replaceAll(RegExp(r'[<>]'), '');

    // Trim and limit length
    sanitized = sanitized.trim();
    if (sanitized.length > 10000) {
      sanitized = sanitized.substring(0, 10000);
    }

    return sanitized;
  }

  // Validate output
  String validateOutput(String output) {
    // Remove any potential script tags
    String validated = output.replaceAll(RegExp(r'<script[^>]*>.*?</script>'), '');

    // Remove any potential HTML
    validated = validated.replaceAll(RegExp(r'<[^>]*>'), '');

    return validated;
  }
}

class SecuritySystem {
  final Guardrails _guardrails = Guardrails();
  final RateLimiter _rateLimiter = RateLimiter();
  final List<SecurityEvent> _events = [];
  final StreamController<SecurityEvent> _eventController =
      StreamController<SecurityEvent>.broadcast();

  Stream<SecurityEvent> get eventStream => _eventController.stream;
  List<SecurityEvent> get events => List.unmodifiable(_events);

  SecuritySystem() {
    _initializeSecurity();
  }

  void _initializeSecurity() {
    // Load security rules
    print('Security system initialized');
  }

  // Check input security
  bool checkInput(String input, {String source = 'user'}) {
    // Rate limiting
    if (!_rateLimiter.allow()) {
      _logEvent(SecurityEvent.create(
        type: ThreatType.rateLimitExceeded,
        level: SecurityLevel.medium,
        description: 'Rate limit exceeded',
        source: source,
      ));
      return false;
    }

    // Check for prompt injection
    if (_guardrails.checkPromptInjection(input)) {
      _logEvent(SecurityEvent.create(
        type: ThreatType.injection,
        level: SecurityLevel.high,
        description: 'Prompt injection attempt detected',
        source: source,
        metadata: {'input': input},
      ));
      return false;
    }

    // Check for sensitive data
    if (_guardrails.containsSensitiveData(input)) {
      _logEvent(SecurityEvent.create(
        type: ThreatType.dataLeak,
        level: SecurityLevel.high,
        description: 'Sensitive data detected in input',
        source: source,
      ));
      return false;
    }

    return true;
  }

  // Sanitize input
  String sanitize(String input) {
    return _guardrails.sanitizeInput(input);
  }

  // Validate output
  String validateOutput(String output) {
    return _guardrails.validateOutput(output);
  }

  // Log security event
  void _logEvent(SecurityEvent event) {
    _events.add(event);
    _eventController.add(event);

    // Print critical events
    if (event.level == SecurityLevel.critical ||
        event.level == SecurityLevel.high) {
      print('SECURITY ${event.level.name.toUpperCase()}: ${event.description}');
    }
  }

  // Get rate limiter status
  Map<String, dynamic> getRateLimiterStatus() {
    return {
      'current_count': _rateLimiter.currentCount,
      'max_requests': _rateLimiter.maxRequests,
      'window': _rateLimiter.window.inSeconds,
    };
  }

  // Get security events by level
  List<SecurityEvent> getEventsByLevel(SecurityLevel level) {
    return _events.where((e) => e.level == level).toList();
  }

  // Get security events by type
  List<SecurityEvent> getEventsByType(ThreatType type) {
    return _events.where((e) => e.type == type).toList();
  }

  // Clear old events
  void clearOldEvents({Duration maxAge = const Duration(days: 7)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    _events.removeWhere((e) => e.timestamp.isBefore(cutoff));
  }

  void dispose() {
    _eventController.close();
  }
}
