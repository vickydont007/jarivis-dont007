class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'created_at': createdAt.toIso8601String(),
    'last_login': lastLogin?.toIso8601String(),
  };

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
    id: map['id'] as String,
    email: map['email'] as String,
    displayName: map['display_name'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    lastLogin: map['last_login'] != null ? DateTime.parse(map['last_login'] as String) : null,
  );
}
