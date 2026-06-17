import 'auth_user.dart';
import 'auth_session.dart';
import 'local_auth_provider.dart';

class AuthService {
  final LocalAuthProvider _provider;

  AuthUser? _currentUser;
  AuthSession? _currentSession;

  AuthService(this._provider);

  AuthUser? get currentUser => _currentUser;
  AuthSession? get currentSession => _currentSession;
  bool get isLoggedIn => _currentUser != null;

  Future<AuthUser?> register(
      String email, String password, String displayName) async {
    final exists = await _provider.emailExists(email);
    if (exists) return null;

    _currentUser = await _provider.createUser(email, password, displayName);
    return _currentUser;
  }

  Future<AuthUser?> login(String email, String password,
      {bool rememberMe = true}) async {
    final user = await _provider.verifyPassword(email, password);
    if (user == null) return null;

    _currentUser = user;
    if (rememberMe) {
      _currentSession = await _provider.createSession(
        user.id,
        rememberMe: true,
      );
    }
    return user;
  }

  Future<void> logout() async {
    if (_currentSession != null) {
      await _provider.deleteSession(_currentSession!.id);
    }
    _currentUser = null;
    _currentSession = null;
  }

  Future<bool> restoreSession() async {
    final session = await _provider.getActiveSession();
    if (session == null) return false;

    final user = await _provider.getUserById(session.userId);
    if (user == null) return false;

    _currentUser = user;
    _currentSession = session;
    await _provider.updateSessionActivity(session.id);
    return true;
  }

  Future<void> updateActivity() async {
    if (_currentSession != null) {
      await _provider.updateSessionActivity(_currentSession!.id);
    }
  }
}
