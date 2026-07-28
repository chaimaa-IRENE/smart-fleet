import '../database_helper.dart';

class QrCodeDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<Map<String, dynamic>?> getByCode(String code) async {
    final db = await _db.database;
    final r = await db.query(
      'qr_codes',
      where: 'code = ? AND actif = 1',
      whereArgs: [code],
      limit: 1,
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<Map<String, dynamic>?> getByVehicule(int vehiculeId) async {
    final db = await _db.database;
    final r = await db.query(
      'qr_codes',
      where: 'vehiculeId = ? AND actif = 1',
      whereArgs: [vehiculeId],
      limit: 1,
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> generate(int vehiculeId, String immatriculation) async {
    final db = await _db.database;
    await db.update(
      'qr_codes',
      {'actif': 0},
      where: 'vehiculeId = ?',
      whereArgs: [vehiculeId],
    );
    final code =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase() +
            vehiculeId.toString().padLeft(4, '0');
    return await db.insert('qr_codes', {
      'code': code,
      'vehiculeId': vehiculeId,
      'immatriculation': immatriculation,
      'actif': 1,
    });
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return await db.query('qr_codes', where: 'actif = 1');
  }
}
