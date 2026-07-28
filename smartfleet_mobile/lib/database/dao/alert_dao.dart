import '../database_helper.dart';

class FleetAlertDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getActive() async {
    final db = await _db.database;
    return await db.query(
      'fleet_alerts',
      where: "statut = 'ACTIVE'",
      orderBy: 'dateCreation DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('fleet_alerts', orderBy: 'dateCreation DESC');
  }

  Future<List<Map<String, dynamic>>> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    return await db.query(
      'fleet_alerts',
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<Map<String, dynamic>> getCounts() async {
    final db = await _db.database;
    final total = await db.rawQuery(
        "SELECT COUNT(*) as c FROM fleet_alerts WHERE statut = 'ACTIVE'",);
    final critiques = await db.rawQuery(
        "SELECT COUNT(*) as c FROM fleet_alerts WHERE statut = 'ACTIVE' AND criticite = 'CRITIQUE'",);
    final moyenne = await db.rawQuery(
        "SELECT COUNT(*) as c FROM fleet_alerts WHERE statut = 'ACTIVE' AND criticite = 'MOYENNE'",);
    final faible = await db.rawQuery(
        "SELECT COUNT(*) as c FROM fleet_alerts WHERE statut = 'ACTIVE' AND criticite = 'FAIBLE'",);
    return {
      'total': total.first['c'],
      'critiques': critiques.first['c'],
      'moyenne': moyenne.first['c'],
      'faible': faible.first['c'],
    };
  }

  Future<int> insert(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('fleet_alerts', data);
  }

  Future<int> resolve(int id, String resoluPar) async {
    final db = await _db.database;
    return await db.update(
      'fleet_alerts',
      {
        'statut': 'RESOLUE',
        'resoluPar': resoluPar,
        'dateResolution': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('fleet_alerts', where: 'id = ?', whereArgs: [id]);
  }
}
