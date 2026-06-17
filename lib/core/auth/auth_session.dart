class AuthSession {
  final String id;
  final String userId;
  final DateTime loginTime;
  final DateTime lastActive;
  final bool rememberMe;

  const AuthSession({
    required this.id,
    required this.userId,
    required this.loginTime,
    required this.lastActive,
    this.rememberMe = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'login_time': loginTime.toIso8601String(),
    'last_active': lastActive.toIso8601String(),
    'remember_me': rememberMe ? '1' : '0',
  };

  factory AuthSession.fromMap(Map<String, dynamic> map) => AuthSession(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    loginTime: DateTime.parse(map['login_time'] as String),
    lastActive: DateTime.parse(map['last_active'] as String),
    rememberMe: (map['remember_me'] as String? ?? '1') == '1',
  );
}
