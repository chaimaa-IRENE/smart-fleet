import '../database/dao/audit_log_dao.dart';

class AuditLogService {
  final AuditLogDao _dao = AuditLogDao();

  Future<int> log(
    String action,
    String entite,
    int entiteId, {
    int? userId,
    String? details,
  }) async {
    return await _dao.log({
      'userId': userId,
      'action': action,
      'entite': entite,
      'entiteId': entiteId,
      'details': details,
      'dateAction': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAll({int limit = 100}) =>
      _dao.getAll(limit: limit);

  Future<List<Map<String, dynamic>>> getByEntity(String entite, int entiteId) =>
      _dao.getByEntity(entite, entiteId);

  Future<List<Map<String, dynamic>>> getByAction(String action) =>
      _dao.getByAction(action);
}
