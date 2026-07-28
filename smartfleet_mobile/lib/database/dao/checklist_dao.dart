import '../database_helper.dart';

class ChecklistDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getSessionsByChauffeur(
    int chauffeurId,
  ) async {
    final db = await _db.database;
    return await db.query(
      'checklist_sessions',
      where: 'chauffeurId = ?',
      whereArgs: [chauffeurId],
      orderBy: 'date DESC',
    );
  }

  Future<Map<String, dynamic>?> getSession(int id) async {
    final db = await _db.database;
    final results =
        await db.query('checklist_sessions', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await _db.database;
    return await db.insert('checklist_sessions', session);
  }

  Future<int> updateSession(int id, Map<String, dynamic> session) async {
    final db = await _db.database;
    return await db.update(
      'checklist_sessions',
      session,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateStatus(int id, String statut) async {
    final db = await _db.database;
    return await db.update(
      'checklist_sessions',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getByStatus(String statut) async {
    final db = await _db.database;
    return await db.query(
      'checklist_sessions',
      where: 'statut = ?',
      whereArgs: [statut],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingValidation() async {
    final db = await _db.database;
    return await db.query(
      'checklist_sessions',
      where: "statut = 'COMPLETE' OR statut = 'REPAIRE'",
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getItems(int sessionId) async {
    final db = await _db.database;
    return await db.query(
      'checklist_items',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await _db.database;
    return await db.insert('checklist_items', item);
  }

  Future<void> insertItems(
      int sessionId, List<Map<String, dynamic>> items,) async {
    final db = await _db.database;
    final batch = db.batch();
    for (var item in items) {
      item['sessionId'] = sessionId;
      batch.insert('checklist_items', item);
    }
    await batch.commit(noResult: true);
  }

  Future<int> updateItem(int id, Map<String, dynamic> item) async {
    final db = await _db.database;
    return await db.update(
      'checklist_items',
      item,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getLatestCompleteByVehicule(int vehiculeId) async {
    final db = await _db.database;
    final r = await db.query(
      'checklist_sessions',
      where: 'vehiculeId = ? AND statut = ?',
      whereArgs: [vehiculeId, 'COMPLETE'],
      orderBy: 'date DESC',
      limit: 1,
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    return [
      {'nom': 'Pneus', 'categorie': 'PNEUS', 'obligatoire': 1},
      {'nom': 'Freins', 'categorie': 'FREINAGE', 'obligatoire': 1},
      {'nom': 'Feux (Éclairage)', 'categorie': 'ECLAIRAGE', 'obligatoire': 1},
      {'nom': 'Extincteur', 'categorie': 'SECURITE', 'obligatoire': 1},
      {'nom': 'Documents', 'categorie': 'DOCUMENTS', 'obligatoire': 1},
      {'nom': 'Carrosserie', 'categorie': 'CARROSSERIE', 'obligatoire': 0},
      {'nom': 'Niveau d\'huile', 'categorie': 'MECANIQUE', 'obligatoire': 1},
      {'nom': 'Batterie', 'categorie': 'ELECTRIQUE', 'obligatoire': 0},
      {'nom': 'Essuie-glaces', 'categorie': 'VISIBILITE', 'obligatoire': 0},
      {'nom': 'Ceintures sécurité', 'categorie': 'SECURITE', 'obligatoire': 1},
    ];
  }
}
