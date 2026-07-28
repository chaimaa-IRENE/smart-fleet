import '../database_helper.dart';

class AnomalieDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll({String? statut}) async {
    final db = await _db.database;
    if (statut != null) {
      return await db.query(
        'anomalies_checkup',
        where: 'statut = ?',
        whereArgs: [statut],
        orderBy: 'dateCreation DESC',
      );
    }
    return await db.query('anomalies_checkup', orderBy: 'dateCreation DESC');
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final r =
        await db.query('anomalies_checkup', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<List<Map<String, dynamic>>> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    return await db.query(
      'anomalies_checkup',
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByCheckup(int checkupId) async {
    final db = await _db.database;
    return await db.query(
      'anomalies_checkup',
      where: 'checkupId = ?',
      whereArgs: [checkupId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await _db.database;
    final total =
        await db.rawQuery('SELECT COUNT(*) as c FROM anomalies_checkup');
    final detectees = await db.rawQuery(
        "SELECT COUNT(*) as c FROM anomalies_checkup WHERE statut = 'DETECTEE'",);
    final enReparation = await db.rawQuery(
        "SELECT COUNT(*) as c FROM anomalies_checkup WHERE statut = 'EN_REPARATION'",);
    final reparees = await db.rawQuery(
        "SELECT COUNT(*) as c FROM anomalies_checkup WHERE statut = 'REPAREE'",);
    final validees = await db.rawQuery(
        "SELECT COUNT(*) as c FROM anomalies_checkup WHERE statut = 'VALIDEE'",);
    final nonReparees = await db.rawQuery(
        "SELECT COUNT(*) as c FROM anomalies_checkup WHERE statut = 'NON_REPAREE'",);
    final totalCount = total.first['c'] as int;
    final valideesCount = validees.first['c'] as int;
    final totalResolues = (reparees.first['c'] as int) + valideesCount;
    final taux = totalCount > 0 ? (totalResolues * 100 / totalCount).toStringAsFixed(1) : '0';
    return {
      'total': totalCount,
      'detectees': detectees.first['c'],
      'enReparation': enReparation.first['c'],
      'reparees': reparees.first['c'],
      'validees': valideesCount,
      'nonReparees': nonReparees.first['c'],
      'tauxReparation': '$taux%',
    };
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('anomalies_checkup', data);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db
        .update('anomalies_checkup', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateStatut(int id, String statut,
      {String? resolutionNotes,}) async {
    final db = await _db.database;
    final data = <String, dynamic>{'statut': statut};
    if (statut == 'REPAREE') {
      data['dateResolution'] = DateTime.now().toIso8601String();
    }
    if (resolutionNotes != null) data['resolutionNotes'] = resolutionNotes;
    return await db
        .update('anomalies_checkup', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db
        .delete('anomalies_checkup', where: 'id = ?', whereArgs: [id]);
  }
}
