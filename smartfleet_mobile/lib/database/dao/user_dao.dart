import '../database_helper.dart';

class UserDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await _db.database;
    final results = await db.query(
      'utilisateurs',
      where: 'email = ? AND motDePasse = ? AND actif = 1',
      whereArgs: [email, password],
    );
    if (results.isEmpty) return null;
    final user = Map<String, dynamic>.from(results.first);
    user.remove('motDePasse');
    return user;
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final results = await db.query(
      'utilisateurs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    final user = Map<String, dynamic>.from(results.first);
    user.remove('motDePasse');
    return user;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    final results = await db.query('utilisateurs', orderBy: 'nom ASC');
    return results
        .map((u) {
          final copy = Map<String, dynamic>.from(u);
          copy.remove('motDePasse');
          return copy;
        })
        .toList();
  }

  Future<int> insert(Map<String, dynamic> user) async {
    final db = await _db.database;
    return await db.insert('utilisateurs', {
      'nom': user['nom'],
      'email': user['email'],
      'motDePasse': user['password'] ?? user['motDePasse'] ?? 'default123',
      'role': user['role'] ?? 'CHAUFFEUR',
      'telephone': user['telephone'],
      'actif': user['actif'] ?? 1,
    });
  }

  Future<int> update(int id, Map<String, dynamic> user) async {
    final db = await _db.database;
    final data = <String, dynamic>{
      'nom': user['nom'],
      'email': user['email'],
      'role': user['role'],
      'telephone': user['telephone'],
      'actif': user['actif'] ?? 1,
    };
    if (user['password'] != null && (user['password'] as String).isNotEmpty) {
      data['motDePasse'] = user['password'];
    }
    return await db
        .update('utilisateurs', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('utilisateurs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getByRole(String role) async {
    final db = await _db.database;
    final results = await db.query(
      'utilisateurs',
      where: 'role = ? AND actif = 1',
      whereArgs: [role],
    );
    return results
        .map((u) {
          final copy = Map<String, dynamic>.from(u);
          copy.remove('motDePasse');
          return copy;
        })
        .toList();
  }
}
