import '../database_helper.dart';

class TicketMaintenanceDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll({String? statut}) async {
    final db = await _db.database;
    if (statut != null) {
      return await db.query(
        'tickets_maintenance',
        where: 'statut = ?',
        whereArgs: [statut],
        orderBy: 'dateCreation DESC',
      );
    }
    return await db.query('tickets_maintenance', orderBy: 'dateCreation DESC');
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final r =
        await db.query('tickets_maintenance', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<List<Map<String, dynamic>>> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    return await db.query(
      'tickets_maintenance',
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await _db.database;
    final total =
        await db.rawQuery('SELECT COUNT(*) as c FROM tickets_maintenance');
    final ouverts = await db.rawQuery(
        "SELECT COUNT(*) as c FROM tickets_maintenance WHERE statut = 'OUVERT'",);
    final enCours = await db.rawQuery(
        "SELECT COUNT(*) as c FROM tickets_maintenance WHERE statut = 'EN_COURS'",);
    final clotures = await db.rawQuery(
        "SELECT COUNT(*) as c FROM tickets_maintenance WHERE statut = 'CLOTURE'",);
    return {
      'total': total.first['c'],
      'ouverts': ouverts.first['c'],
      'enCours': enCours.first['c'],
      'clotures': clotures.first['c'],
    };
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('tickets_maintenance', data);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db
        .update('tickets_maintenance', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateStatut(int id, String statut) async {
    final db = await _db.database;
    final data = <String, dynamic>{'statut': statut};
    if (statut == 'EN_COURS') {
      data['dateDebut'] = DateTime.now().toIso8601String();
    }
    if (statut == 'CLOTURE') data['dateFin'] = DateTime.now().toIso8601String();
    return await db
        .update('tickets_maintenance', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db
        .delete('tickets_maintenance', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getInterventions(int ticketId) async {
    final db = await _db.database;
    return await db
        .query('interventions', where: 'ticketId = ?', whereArgs: [ticketId]);
  }

  Future<int> insertIntervention(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('interventions', data);
  }
}
