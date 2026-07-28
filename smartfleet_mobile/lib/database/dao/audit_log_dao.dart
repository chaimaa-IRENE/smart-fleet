import '../database_helper.dart';

class AuditLogDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> log(Map<String, dynamic> data) async {
    final db = await _db.database;
    return await db.insert('audit_logs', data);
  }

  Future<List<Map<String, dynamic>>> getAll({int limit = 100}) async {
    final db = await _db.database;
    return await db.query(
      'audit_logs',
      orderBy: 'dateAction DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getByEntity(
      String entite, int entiteId,) async {
    final db = await _db.database;
    return await db.query(
      'audit_logs',
      where: 'entite = ? AND entiteId = ?',
      whereArgs: [entite, entiteId],
      orderBy: 'dateAction DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getByAction(String action) async {
    final db = await _db.database;
    return await db.query(
      'audit_logs',
      where: 'action = ?',
      whereArgs: [action],
      orderBy: 'dateAction DESC',
    );
  }
}
