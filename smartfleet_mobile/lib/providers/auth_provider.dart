import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  AuthStatus _status = AuthStatus.uninitialized;
  Map<String, dynamic>? _user;
  String? _error;

  AuthProvider(this._authService);

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  int? get userId => _user?['id'] as int?;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> init() async {
    await _authService.init();
    if (_authService.isLoggedIn) {
      _user = _authService.currentUser;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.login(email, password);
      if (_user != null) {
        _status = AuthStatus.authenticated;
      } else {
        _error = 'Email ou mot de passe incorrect';
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _error = e.toString();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> loadUser(Map<String, dynamic> user) async {
    _user = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  bool hasRole(String role) => _user?['role'] == role;
  bool hasAnyRole(List<String> roles) => roles.contains(_user?['role']);
  String get role => _user?['role'] as String? ?? '';

  Future<List<Map<String, dynamic>>> getUsers() => _authService.getUsers();
  Future<int> createUser(Map<String, dynamic> user) =>
      _authService.createUser(user);
  Future<int> updateUser(int id, Map<String, dynamic> user) =>
      _authService.updateUser(id, user);
  Future<int> deleteUser(int id) => _authService.deleteUser(id);
}
