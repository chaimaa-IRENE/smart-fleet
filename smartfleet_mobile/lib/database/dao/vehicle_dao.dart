import '../database_helper.dart';

class VehicleDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('vehicules', orderBy: 'immatriculation ASC');
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final results =
        await db.query('vehicules', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getByImmat(String immat) async {
    final db = await _db.database;
    final results = await db
        .query('vehicules', where: 'immatriculation = ?', whereArgs: [immat]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getByChauffeur(int chauffeurId) async {
    final db = await _db.database;
    return await db.query(
      'vehicules',
      where: 'chauffeurId = ?',
      whereArgs: [chauffeurId],
    );
  }

  Future<int> insert(Map<String, dynamic> vehicle) async {
    final db = await _db.database;
    return await db.insert('vehicules', vehicle);
  }

  Future<int> update(int id, Map<String, dynamic> vehicle) async {
    final db = await _db.database;
    return await db
        .update('vehicules', vehicle, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateByImmat(String immat, Map<String, dynamic> vehicle) async {
    final db = await _db.database;
    return await db.update(
      'vehicules',
      vehicle,
      where: 'immatriculation = ?',
      whereArgs: [immat],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('vehicules', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM vehicules');
    return result.first['c'] as int;
  }
}
