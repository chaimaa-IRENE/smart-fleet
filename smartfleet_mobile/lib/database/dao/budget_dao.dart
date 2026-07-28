import '../database_helper.dart';

class BudgetDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('budget_trimestriel', orderBy: 'dateCreation DESC');
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final db = await _db.database;
    final results =
        await db.query('budget_trimestriel', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getCurrent() async {
    final db = await _db.database;
    final results = await db.query(
      'budget_trimestriel',
      where: "statut = 'ACTIF'",
      orderBy: 'dateCreation DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insert(Map<String, dynamic> budget) async {
    final db = await _db.database;
    return await db.insert('budget_trimestriel', budget);
  }

  Future<int> update(int id, Map<String, dynamic> budget) async {
    final db = await _db.database;
    return await db.update(
      'budget_trimestriel',
      budget,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateUtilisation(int id, double montant) async {
    final db = await _db.database;
    return await db.update(
      'budget_trimestriel',
      {'montantUtilise': montant},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> recalculerUtilisation(int budgetId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(coutReel), 0) as total
      FROM declarations
      WHERE statut != 'REJETEE'
        AND dateCreation >= (
          SELECT dateCreation FROM budget_trimestriel WHERE id = ?
        )
    ''',
      [budgetId],
    );
    final total = result.first['total'] as num;
    await db.update(
      'budget_trimestriel',
      {'montantUtilise': total.toDouble()},
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }

  Future<List<Map<String, dynamic>>> getByProvider(int budgetId) async {
    final db = await _db.database;
    final budget = await getById(budgetId);
    if (budget == null) return [];
    return await db.rawQuery('''
      SELECT COALESCE(d.prestataireNom, 'Non assigné') as prestataire,
             COALESCE(SUM(d.coutReel), 0) as total
      FROM declarations d
      WHERE d.statut != 'REJETEE'
      GROUP BY d.prestataireNom
      ORDER BY total DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getByType(int budgetId) async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT d.typePanne as type,
             COALESCE(SUM(d.coutReel), 0) as total
      FROM declarations d
      WHERE d.statut != 'REJETEE'
      GROUP BY d.typePanne
      ORDER BY total DESC
    ''');
  }
}
