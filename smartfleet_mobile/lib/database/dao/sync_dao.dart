import 'dart:convert';
import '../database_helper.dart';

class SyncDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> addToQueue(
    String tableName,
    String action,
    int? recordId, {
    Map<String, dynamic>? payload,
  }) async {
    final db = await _db.database;
    final data = <String, dynamic>{
      'tableName': tableName,
      'action': action,
      'recordId': recordId,
      'payload': payload != null ? jsonEncode(Map<String, dynamic>.from(payload)) : null,
      'status': 'PENDING',
    };
    await db.insert('sync_queue', data);
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final db = await _db.database;
    return await db.query(
      'sync_queue',
      where: "status = 'PENDING'",
      orderBy: 'dateCreation ASC',
    );
  }

  Future<void> markCompleted(int id) async {
    final db = await _db.database;
    await db.update(
      'sync_queue',
      {'status': 'COMPLETED'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id) async {
    final db = await _db.database;
    await db.update(
      'sync_queue',
      {'status': 'FAILED'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pendingCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'PENDING'",);
    return result.first['c'] as int;
  }

  Future<void> clearCompleted() async {
    final db = await _db.database;
    await db.delete('sync_queue', where: "status IN ('COMPLETED', 'FAILED')");
  }
}
