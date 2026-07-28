import '../database/dao/anomalie_dao.dart';
import '../database/dao/audit_log_dao.dart';

class AnomalieService {
  final AnomalieDao _dao = AnomalieDao();
  final AuditLogDao _auditDao = AuditLogDao();

  Future<List<Map<String, dynamic>>> getAll({String? statut}) =>
      _dao.getAll(statut: statut);
  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);
  Future<List<Map<String, dynamic>>> getByVehicule(int id) =>
      _dao.getByVehicule(id);
  Future<List<Map<String, dynamic>>> getByCheckup(int id) =>
      _dao.getByCheckup(id);
  Future<Map<String, dynamic>> getStats() => _dao.getStats();

  Future<int> create(Map<String, dynamic> data) async {
    data['code'] = 'ANOM-${DateTime.now().millisecondsSinceEpoch}';
    data['dateCreation'] = DateTime.now().toIso8601String();
    data['statut'] = 'DETECTEE';
    final id = await _dao.insert(data);
    await _auditDao.log({
      'action': 'CREATE_ANOMALIE',
      'entite': 'ANOMALIE',
      'entiteId': id,
    });
    return id;
  }

  Future<int> takeCharge(int id, String assignedTo) async {
    final result = await _dao.update(id, {
      'statut': 'EN_REPARATION',
      'assignedTo': assignedTo,
    });
    await _auditDao.log({
      'action': 'TAKE_CHARGE_ANOMALIE',
      'entite': 'ANOMALIE',
      'entiteId': id,
      'details': assignedTo,
    });
    return result;
  }

  Future<int> resolve(int id, {String? notes}) async {
    final result =
        await _dao.updateStatut(id, 'REPAREE', resolutionNotes: notes);
    await _auditDao.log({
      'action': 'RESOLVE_ANOMALIE',
      'entite': 'ANOMALIE',
      'entiteId': id,
      'details': notes,
    });
    return result;
  }

  Future<int> reject(int id, {String? raison}) async {
    final result = await _dao.updateStatut(id, 'NON_REPAREE');
    await _auditDao.log({
      'action': 'REJECT_ANOMALIE',
      'entite': 'ANOMALIE',
      'entiteId': id,
      'details': raison,
    });
    return result;
  }

  Future<int> delete(int id) => _dao.delete(id);

  Future<int> validate(int id) async {
    final result = await _dao.updateStatut(id, 'VALIDEE');
    await _auditDao.log({
      'action': 'VALIDATE_ANOMALIE',
      'entite': 'ANOMALIE',
      'entiteId': id,
    });
    return result;
  }
}
