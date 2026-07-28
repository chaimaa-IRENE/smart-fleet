import '../database/dao/tournee_dao.dart';
import '../database/dao/depart_dao.dart';
import '../database/dao/audit_log_dao.dart';

class TourneeService {
  final TourneeDao _dao = TourneeDao();
  final DepartDao _departDao = DepartDao();
  final AuditLogDao _auditDao = AuditLogDao();

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();
  Future<List<Map<String, dynamic>>> getByChauffeur(int id) =>
      _dao.getByChauffeur(id);
  Future<List<Map<String, dynamic>>> getByVehicule(int id) =>
      _dao.getByVehicule(id);
  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);

  Future<int> create(Map<String, dynamic> data) async {
    data['numero'] =
        'TOUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final id = await _dao.insert(data);
    await _auditDao.log({
      'action': 'CREATE_TOURNEE',
      'entite': 'TOURNEE',
      'entiteId': id,
      'details': 'Tournee ${data['numero']} créée',
    });
    return id;
  }

  Future<int> update(int id, Map<String, dynamic> data) =>
      _dao.update(id, data);

  Future<int> demarrer(int id) async {
    final result = await _dao.update(id, {
      'statut': 'EN_COURS',
      'dateDebut': DateTime.now().toIso8601String(),
    });
    await _auditDao.log({
      'action': 'DEMARRER_TOURNEE',
      'entite': 'TOURNEE',
      'entiteId': id,
    });
    return result;
  }

  Future<int> terminer(int id, {double? distanceReelle}) async {
    final data = <String, dynamic>{
      'statut': 'TERMINEE',
      'dateFin': DateTime.now().toIso8601String(),
    };
    if (distanceReelle != null) data['distanceReelle'] = distanceReelle;
    final result = await _dao.update(id, data);
    await _auditDao.log({
      'action': 'TERMINER_TOURNEE',
      'entite': 'TOURNEE',
      'entiteId': id,
    });
    return result;
  }

  Future<int> annuler(int id, {String? raison}) async {
    final result = await _dao.updateStatut(id, 'ANNULEE');
    await _auditDao.log({
      'action': 'ANNULER_TOURNEE',
      'entite': 'TOURNEE',
      'entiteId': id,
      'details': raison,
    });
    return result;
  }

  Future<int> delete(int id) => _dao.delete(id);

  Future<int> enregistrerDepart(Map<String, dynamic> data) async {
    return await _departDao.enregistrer(data);
  }

  Future<List<Map<String, dynamic>>> getDepartsToday() => _departDao.getToday();
  Future<List<Map<String, dynamic>>> getAllDeparts() => _departDao.getAll();
}
