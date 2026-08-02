import '../database_helper.dart';

class DeclarationDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll({String? statut}) async {
    final db = await _db.database;
    if (statut != null) {
      return await db.query(
        'declarations',
        where: 'statut = ?',
        whereArgs: [statut],
        orderBy: 'dateCreation DESC',
      );
    }
    return await db.query('declarations', orderBy: 'dateCreation DESC');
  }

  Future<List<Map<String, dynamic>>> getByChauffeur(int chauffeurId) async {
    final db = await _db.database;
    return await db.query(
      'declarations',
      where: 'chauffeurId = ?',
      whereArgs: [chauffeurId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByPrestataire(int prestataireId) async {
    final db = await _db.database;
    return await db.query(
      'declarations',
      where: 'prestataireId = ?',
      whereArgs: [prestataireId],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByVehicle(String immat) async {
    final db = await _db.database;
    return await db.query(
      'declarations',
      where: 'immatriculation = ?',
      whereArgs: [immat],
      orderBy: 'dateCreation DESC',
    );
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final results =
        await db.query('declarations', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insert(Map<String, dynamic> declaration) async {
    final db = await _db.database;
    return await db.insert('declarations', declaration);
  }

  Future<int> update(int id, Map<String, dynamic> declaration) async {
    final db = await _db.database;
    final copy = Map<String, dynamic>.from(declaration);
    try {
      return await db.update(
        'declarations',
        copy,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('declarations.update(id=$id, keys=${copy.keys}): $e');
    }
  }

  Future<int> updateStatus(
    int id,
    String statut, {
    String? dateCloture,
    double? coutReel,
  }) async {
    final db = await _db.database;
    final data = <String, dynamic>{'statut': statut};
    if (dateCloture != null) data['dateCloture'] = dateCloture;
    if (coutReel != null) data['coutReel'] = coutReel;
    return await db
        .update('declarations', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('declarations', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await _db.database;
    final total = await db.rawQuery('SELECT COUNT(*) as c FROM declarations');
    final enAttente = await db.rawQuery(
      "SELECT COUNT(*) as c FROM declarations WHERE statut = 'EN_ATTENTE'",
    );
    final enCours = await db.rawQuery(
      "SELECT COUNT(*) as c FROM declarations WHERE statut IN ('PRISE_EN_CHARGE','EN_COURS','EN_VALIDATION','TRAITE')",
    );
    final cloture = await db.rawQuery(
      "SELECT COUNT(*) as c FROM declarations WHERE statut = 'CLOTURE'",
    );
    final rejetee = await db.rawQuery(
      "SELECT COUNT(*) as c FROM declarations WHERE statut = 'REJETEE'",
    );
    final retournee = await db.rawQuery(
      "SELECT COUNT(*) as c FROM declarations WHERE statut = 'RETOURNEE'",
    );
    final coutTotal = await db
        .rawQuery('SELECT COALESCE(SUM(coutReel), 0) as c FROM declarations');
    return {
      'total': total.first['c'],
      'en_attente': enAttente.first['c'],
      'en_cours': enCours.first['c'],
      'cloture': cloture.first['c'],
      'rejetee': rejetee.first['c'],
      'retournee': retournee.first['c'],
      'cout_total': coutTotal.first['c'],
    };
  }

  Future<List<Map<String, dynamic>>> getEvolution(
    String immat, {
    String? mois1,
    String? mois2,
  }) async {
    final db = await _db.database;
    String where = "immatriculation = ? AND statut != 'REJETEE'";
    List<dynamic> args = [immat];
    if (mois1 != null && mois2 != null) {
      where +=
          ' AND substr(dateCreation, 1, 7) >= ? AND substr(dateCreation, 1, 7) <= ?';
      args.addAll([mois1, mois2]);
    }
    return await db.rawQuery(
      '''
      SELECT substr(dateCreation, 1, 7) as mois,
             COALESCE(SUM(coutReel), 0) as coutTotal,
             COUNT(*) as nombrePannes
      FROM declarations
      WHERE $where
      GROUP BY mois
      ORDER BY mois ASC
    ''',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getAvailableMonths(String immat) async {
    final db = await _db.database;
    return await db.rawQuery(
      '''
      SELECT DISTINCT substr(dateCreation, 1, 7) as mois
      FROM declarations
      WHERE immatriculation = ? AND statut != 'REJETEE'
      ORDER BY mois ASC
    ''',
      [immat],
    );
  }
}
