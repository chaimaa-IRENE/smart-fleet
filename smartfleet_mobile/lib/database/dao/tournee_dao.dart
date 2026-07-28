import '../database_helper.dart';

class TourneeDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('tournees', orderBy: 'dateCreation DESC');
  }

  Future<List<Map<String, dynamic>>> getByChauffeur(int chauffeurId) async {
    final db = await _db.database;
    return await db.query(
      'tournees',
      where: 'chauffeurId = ?',
      whereArgs: [chauffeurId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    return await db.query(
      'tournees',
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final r = await db.query('tournees', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('tournees', data);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.update('tournees', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateStatut(int id, String statut) async {
    final db = await _db.database;
    return await db.update('tournees', {'statut': statut},
        where: 'id = ?', whereArgs: [id],);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('tournees', where: 'id = ?', whereArgs: [id]);
  }
}
