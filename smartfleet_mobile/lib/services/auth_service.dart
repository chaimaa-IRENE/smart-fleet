import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/dao/user_dao.dart';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final UserDao _userDao = UserDao();
  Map<String, dynamic>? _currentUser;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  static const _sessionKey = 'session_user';

  Future<void> init() async {
    final data = await _storage.read(key: _sessionKey);
    if (data != null) {
      _currentUser = jsonDecode(data) as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final user = await _userDao.login(email, password);
    if (user != null) {
      _currentUser = user;
      await _storage.write(key: _sessionKey, value: jsonEncode(user));
    }
    return user;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _storage.delete(key: _sessionKey);
  }

  bool hasRole(String role) => _currentUser?['role'] == role;
  bool hasAnyRole(List<String> roles) => roles.contains(_currentUser?['role']);

  Future<List<Map<String, dynamic>>> getUsers() => _userDao.getAll();
  Future<Map<String, dynamic>?> getUserById(int id) => _userDao.getById(id);
  Future<int> createUser(Map<String, dynamic> user) => _userDao.insert(user);
  Future<int> updateUser(int id, Map<String, dynamic> user) =>
      _userDao.update(id, user);
  Future<int> deleteUser(int id) => _userDao.delete(id);
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) =>
      _userDao.getByRole(role);
}
