import '../database/dao/checkup_dao.dart';
import '../database/dao/anomalie_dao.dart';
import '../database/dao/alert_dao.dart';
import '../database/dao/audit_log_dao.dart';

class CheckupService {
  final CheckupDao _dao = CheckupDao();
  final AnomalieDao _anomalieDao = AnomalieDao();
  final FleetAlertDao _alertDao = FleetAlertDao();
  final AuditLogDao _auditDao = AuditLogDao();

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();
  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);
  Future<List<Map<String, dynamic>>> getByVehicule(int id) =>
      _dao.getByVehicule(id);
  Future<List<Map<String, dynamic>>> getByChauffeur(int id) =>
      _dao.getByChauffeur(id);
  Future<Map<String, dynamic>?> getLatestByVehicule(int id) =>
      _dao.getLatestByVehicule(id);
  Future<Map<String, dynamic>> getStats() => _dao.getStats();
  Future<List<Map<String, dynamic>>> getDetails(int checkupId) =>
      _dao.getDetails(checkupId);

  Future<int> create(
      Map<String, dynamic> data, List<Map<String, dynamic>> details,) async {
    final code = 'CHK-${DateTime.now().millisecondsSinceEpoch}';
    data['code'] = code;
    data['dateCheckup'] = DateTime.now().toIso8601String();

    bool conforme = true;
    for (var d in details) {
      if (d['conforme'] == 0 || d['conforme'] == false) {
        conforme = false;
        break;
      }
    }
    data['conforme'] = conforme ? 1 : 0;

    final id = await _dao.insert(data);
    await _dao.insertDetails(id, details);

    if (!conforme) {
      for (var d in details
          .where((d) => d['conforme'] == 0 || d['conforme'] == false)) {
        await _anomalieDao.insert({
          'code':
              'ANOM-${DateTime.now().millisecondsSinceEpoch}-${d['element']}',
          'checkupId': id,
          'element': d['element'],
          'categorie': d['categorie'] ?? '',
          'criticite': d['criticite'] ?? 'MOYENNE',
          'description': d['observation'] ?? 'Non conforme',
          'vehiculeId': data['vehiculeId'],
          'immatriculation': data['immatriculation'] ?? '',
          'chauffeurId': data['chauffeurId'],
          'chauffeurNom': data['chauffeurNom'] ?? '',
          'statut': 'OUVERTE',
        });
      }
      await _alertDao.insert({
        'vehiculeId': data['vehiculeId'],
        'immatriculation': data['immatriculation'] ?? '',
        'type': 'CHECKUP_NON_CONFORME',
        'criticite': 'MOYENNE',
        'message': 'Checkup non conforme pour ${data['immatriculation'] ?? ''}',
        'statut': 'ACTIVE',
      });
    }

    await _auditDao.log({
      'action': 'CREATE_CHECKUP',
      'entite': 'CHECKUP',
      'entiteId': id,
      'details': 'Conforme: $conforme',
    });

    return id;
  }

  Future<int> update(int id, Map<String, dynamic> data) =>
      _dao.update(id, data);
  Future<int> delete(int id) => _dao.delete(id);
}
