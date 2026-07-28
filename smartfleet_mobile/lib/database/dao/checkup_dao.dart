import '../database_helper.dart';

class CheckupDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('checkups', orderBy: 'dateCheckup DESC');
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final r = await db.query('checkups', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<List<Map<String, dynamic>>> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    return await db.query(
      'checkups',
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
      orderBy: 'dateCheckup DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByChauffeur(int chauffeurId) async {
    final db = await _db.database;
    return await db.query(
      'checkups',
      where: 'chauffeurId = ?',
      whereArgs: [chauffeurId],
      orderBy: 'dateCheckup DESC',
    );
  }

  Future<Map<String, dynamic>?> getLatestByVehicule(int vehiculeId) async {
    final db = await _db.database;
    final r = await db.query(
      'checkups',
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
      orderBy: 'dateCheckup DESC',
      limit: 1,
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await _db.database;
    final total = await db.rawQuery('SELECT COUNT(*) as c FROM checkups');
    final conforme = await db
        .rawQuery('SELECT COUNT(*) as c FROM checkups WHERE conforme = 1');
    final nonConforme = await db
        .rawQuery('SELECT COUNT(*) as c FROM checkups WHERE conforme = 0');
    return {
      'total': total.first['c'],
      'conforme': conforme.first['c'],
      'nonConforme': nonConforme.first['c'],
      'taux': total.first['c'] as int > 0
          ? ((conforme.first['c'] as int) / (total.first['c'] as int) * 100)
          : 100.0,
    };
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('checkups', data);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.update('checkups', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('checkups', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDetails(int checkupId) async {
    final db = await _db.database;
    return await db.query('checkup_details',
        where: 'checkupId = ?', whereArgs: [checkupId],);
  }

  Future<int> insertDetail(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('checkup_details', data);
  }

  Future<void> insertDetails(
      int checkupId, List<Map<String, dynamic>> details,) async {
    final db = await _db.database;
    final batch = db.batch();
    for (var d in details) {
      d['checkupId'] = checkupId;
      batch.insert('checkup_details', d);
    }
    await batch.commit(noResult: true);
  }
}
