import '../database/dao/user_dao.dart';

class UserService {
  final UserDao _dao = UserDao();

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();

  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);

  Future<List<Map<String, dynamic>>> getByRole(String role) => _dao.getByRole(role);

  Future<Map<String, dynamic>?> getByMatricule(String matricule) =>
      _dao.getByMatricule(matricule);

  Future<int> create(Map<String, dynamic> data) => _dao.insert(data);

  Future<int> update(int id, Map<String, dynamic> data) => _dao.update(id, data);

  Future<int> delete(int id) => _dao.delete(id);
}
