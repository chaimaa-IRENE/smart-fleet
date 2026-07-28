import '../database_helper.dart';

class DepartDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> enregistrer(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('departs_historique', data);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('departs_historique', orderBy: 'dateDepart DESC');
  }

  Future<List<Map<String, dynamic>>> getByChauffeur(int chauffeurId) async {
    final db = await _db.database;
    return await db.query(
      'departs_historique',
      where: 'chauffeurId = ?',
      whereArgs: [chauffeurId],
      orderBy: 'dateDepart DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByVehicule(
      String immatriculation,) async {
    final db = await _db.database;
    return await db.query(
      'departs_historique',
      where: 'immatriculation = ?',
      whereArgs: [immatriculation],
      orderBy: 'dateDepart DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getToday() async {
    final db = await _db.database;
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    return await db.query(
      'departs_historique',
      where: 'dateDepart >= ?',
      whereArgs: [start],
      orderBy: 'dateDepart DESC',
    );
  }
}
