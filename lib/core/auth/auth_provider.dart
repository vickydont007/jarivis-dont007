import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'auth_user.dart';
import 'local_auth_provider.dart';

// Forward declaration - set by workspace_loader.dart
typedef AuthCleanupCallback = Future<void> Function();
typedef AuthLoginCallback = Future<void> Function(String userId);

AuthCleanupCallback? _logoutCleanup;
AuthLoginCallback? _loginLoadCallback;

void setLogoutCleanup(AuthCleanupCallback callback) {
  _logoutCleanup = callback;
}

void setLoginLoadCallback(AuthLoginCallback callback) {
  _loginLoadCallback = callback;
}

final localAuthProvider = Provider<LocalAuthProvider>((ref) {
  return LocalAuthProvider();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final provider = ref.read(localAuthProvider);
  return AuthService(provider);
});

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AuthUser? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final restored = await _authService.restoreSession();
    if (restored) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _authService.currentUser,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<String?> register(
      String email, String password, String displayName) async {
    state = state.copyWith(error: null);
    final user = await _authService.register(email, password, displayName);
    if (user == null) {
      state = state.copyWith(error: 'Email already registered');
      return 'Email already registered';
    }
    state = AuthState(status: AuthStatus.authenticated, user: user);
    if (_loginLoadCallback != null && user.id.isNotEmpty) {
      await _loginLoadCallback!(user.id);
    }
    return null;
  }

  Future<String?> login(String email, String password,
      {bool rememberMe = true}) async {
    state = state.copyWith(error: null);
    final user =
        await _authService.login(email, password, rememberMe: rememberMe);
    if (user == null) {
      state = state.copyWith(error: 'Invalid email or password');
      return 'Invalid email or password';
    }
    state = AuthState(status: AuthStatus.authenticated, user: user);
    if (_loginLoadCallback != null && user.id.isNotEmpty) {
      await _loginLoadCallback!(user.id);
    }
    return null;
  }

  Future<void> logout() async {
    if (_logoutCleanup != null) {
      await _logoutCleanup!();
    }
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});
