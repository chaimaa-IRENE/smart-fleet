import '../database/dao/alert_dao.dart';
import '../database/dao/blocking_dao.dart';

class FleetAlertService {
  final FleetAlertDao _alertDao = FleetAlertDao();
  final BlockingDao _blockingDao = BlockingDao();

  Future<List<Map<String, dynamic>>> getActive() => _alertDao.getActive();
  Future<List<Map<String, dynamic>>> getAll() => _alertDao.getAll();
  Future<List<Map<String, dynamic>>> getByVehicule(int id) =>
      _alertDao.getByVehicule(id);
  Future<Map<String, dynamic>> getCounts() => _alertDao.getCounts();

  Future<int> create(Map<String, dynamic> data) async {
    data['dateCreation'] = DateTime.now().toIso8601String();
    data['statut'] = 'ACTIVE';
    return await _alertDao.insert(data);
  }

  Future<int> resolve(int id, String resoluPar) =>
      _alertDao.resolve(id, resoluPar);

  Future<int> blockVehicle(
    int vehiculeId,
    String immatriculation,
    String raison,
    int bloquePar,
  ) async {
    return await _blockingDao.block({
      'vehiculeId': vehiculeId,
      'immatriculation': immatriculation,
      'raison': raison,
      'niveau': 'IMMEDIAT',
      'bloquePar': bloquePar,
    });
  }

  Future<int> unblockVehicle(int vehiculeId, int debloquePar) =>
      _blockingDao.unblock(vehiculeId, debloquePar);

  Future<List<Map<String, dynamic>>> getActiveBlockings() =>
      _blockingDao.getActive();
  Future<Map<String, dynamic>?> getActiveBlocking(int vehiculeId) =>
      _blockingDao.getActiveByVehicule(vehiculeId);
}
