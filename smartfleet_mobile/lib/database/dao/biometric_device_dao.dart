import '../database_helper.dart';

class BiometricDeviceDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Map<String, dynamic> device) async {
    final db = await _db.database;
    return await db.insert('biometric_devices', {
      'userId': device['userId'],
      'deviceId': device['deviceId'],
      'deviceName': device['deviceName'],
      'platform': device['platform'],
      'biometricEnabled': device['biometricEnabled'] ?? 1,
      'lastUsed': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getByUserId(int userId) async {
    final db = await _db.database;
    final results = await db.query(
      'biometric_devices',
      where: 'userId = ? AND biometricEnabled = 1',
      whereArgs: [userId],
    );
    if (results.isEmpty) return null;
    return Map<String, dynamic>.from(results.first);
  }

  Future<List<Map<String, dynamic>>> getAllByUserId(int userId) async {
    final db = await _db.database;
    final results = await db.query(
      'biometric_devices',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'dateCreated DESC',
    );
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllEnabled() async {
    final db = await _db.database;
    final results = await db.query(
      'biometric_devices',
      where: 'biometricEnabled = 1',
      orderBy: 'lastUsed DESC',
    );
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllWithUsers() async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT b.*, u.nom, u.email, u.role
      FROM biometric_devices b
      JOIN utilisateurs u ON b.userId = u.id
      ORDER BY b.lastUsed DESC
    ''');
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<int> disable(int id) async {
    final db = await _db.database;
    return await db.update(
      'biometric_devices',
      {'biometricEnabled': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> disableByUserId(int userId) async {
    final db = await _db.database;
    return await db.update(
      'biometric_devices',
      {'biometricEnabled': 0},
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete(
      'biometric_devices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLastUsed(int id) async {
    final db = await _db.database;
    await db.update(
      'biometric_devices',
      {'lastUsed': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countEnabled() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM biometric_devices WHERE biometricEnabled = 1',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
