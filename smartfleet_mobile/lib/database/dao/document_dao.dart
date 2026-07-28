import '../database_helper.dart';

class DocumentVehiculeDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query(
      'documents_vehicule',
      where: 'archived = 0',
      orderBy: 'typeDocument ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    return await db.query(
      'documents_vehicule',
      where: 'vehiculeId = ? AND archived = 0',
      whereArgs: [vehiculeId],
    );
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final r =
        await db.query('documents_vehicule', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<List<Map<String, dynamic>>> getExpiringSoon(int days) async {
    final db = await _db.database;
    final deadline = DateTime.now().add(Duration(days: days));
    return await db.query(
      'documents_vehicule',
      where:
          'dateExpiration IS NOT NULL AND dateExpiration <= ? AND archived = 0',
      whereArgs: [deadline.toIso8601String()],
      orderBy: 'dateExpiration ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getExpired() async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'documents_vehicule',
      where:
          'dateExpiration IS NOT NULL AND dateExpiration < ? AND archived = 0',
      whereArgs: [now],
      orderBy: 'dateExpiration ASC',
    );
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await _db.database;
    final total = await db.rawQuery(
        'SELECT COUNT(*) as c FROM documents_vehicule WHERE archived = 0',);
    final byType = await db.rawQuery(
      'SELECT typeDocument, COUNT(*) as c FROM documents_vehicule WHERE archived = 0 GROUP BY typeDocument',
    );
    final expired = await db.rawQuery(
      "SELECT COUNT(*) as c FROM documents_vehicule WHERE dateExpiration < datetime('now') AND archived = 0",
    );
    return {
      'total': total.first['c'],
      'byType': byType,
      'expired': expired.first['c'],
    };
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('documents_vehicule', data);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db
        .update('documents_vehicule', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archive(int id) async {
    final db = await _db.database;
    return await db.update(
      'documents_vehicule',
      {'archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db
        .delete('documents_vehicule', where: 'id = ?', whereArgs: [id]);
  }
}
