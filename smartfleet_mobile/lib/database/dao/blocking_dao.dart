import '../database_helper.dart';

class BlockingDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getActive() async {
    final db = await _db.database;
    return await db.query(
      'vehicle_blockings',
      where: 'actif = 1',
      orderBy: 'bloqueLe DESC',
    );
  }

  Future<Map<String, dynamic>?> getActiveByVehicule(int vehiculeId) async {
    final db = await _db.database;
    final r = await db.query(
      'vehicle_blockings',
      where: 'vehiculeId = ? AND actif = 1',
      whereArgs: [vehiculeId],
      limit: 1,
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> block(Map<String, dynamic> data) async {
    final db = await _db.database;
    final id = await db.insert('vehicle_blockings', data);
    await db.update(
      'vehicules',
      {'statut': 'BLOQUE'},
      where: 'id = ?',
      whereArgs: [data['vehiculeId']],
    );
    return id;
  }

  Future<int> unblock(int vehiculeId, int debloquePar) async {
    final db = await _db.database;
    final result = await db.update(
      'vehicle_blockings',
      {
        'actif': 0,
        'debloquePar': debloquePar,
        'debloqueLe': DateTime.now().toIso8601String(),
      },
      where: 'vehiculeId = ? AND actif = 1',
      whereArgs: [vehiculeId],
    );
    await db.update(
      'vehicules',
      {'statut': 'ACTIF'},
      where: 'id = ?',
      whereArgs: [vehiculeId],
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('vehicle_blockings', orderBy: 'bloqueLe DESC');
  }
}
