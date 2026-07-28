import '../database/dao/vehicle_dao.dart';
import '../database/dao/sync_dao.dart';

class VehicleService {
  final VehicleDao _dao = VehicleDao();
  final SyncDao _syncDao = SyncDao();

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();

  Future<List<Map<String, dynamic>>> getMyVehicles(int chauffeurId) =>
      _dao.getByChauffeur(chauffeurId);

  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);

  Future<Map<String, dynamic>?> getByImmat(String immat) =>
      _dao.getByImmat(immat);

  Future<List<Map<String, dynamic>>> getByChauffeur(int chauffeurId) =>
      _dao.getByChauffeur(chauffeurId);

  Future<int> create(Map<String, dynamic> data) async {
    final id = await _dao.insert(data);
    await _syncDao.addToQueue('vehicules', 'INSERT', id, payload: data);
    return id;
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final result = await _dao.update(id, data);
    await _syncDao.addToQueue('vehicules', 'UPDATE', id, payload: data);
    return result;
  }

  Future<int> delete(int id) async {
    final result = await _dao.delete(id);
    await _syncDao.addToQueue('vehicules', 'DELETE', id);
    return result;
  }

  Future<int> count() => _dao.count();
}
