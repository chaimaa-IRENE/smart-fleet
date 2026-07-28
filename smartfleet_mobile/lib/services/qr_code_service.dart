import '../database/dao/qr_code_dao.dart';
import '../database/dao/vehicle_dao.dart';

class QrCodeService {
  final QrCodeDao _dao = QrCodeDao();
  final VehicleDao _vehicleDao = VehicleDao();

  Future<Map<String, dynamic>?> scan(String code) async {
    final qr = await _dao.getByCode(code);
    if (qr == null) return null;
    final vehicule = await _vehicleDao.getById(qr['vehiculeId'] as int);
    if (vehicule != null) {
      return {
        'qr': qr,
        'vehicule': vehicule,
      };
    }
    return {'qr': qr};
  }

  Future<int> generate(int vehiculeId) async {
    final vehicule = await _vehicleDao.getById(vehiculeId);
    if (vehicule == null) throw Exception('Véhicule introuvable');
    return await _dao.generate(
        vehiculeId, vehicule['immatriculation'] as String,);
  }

  Future<Map<String, dynamic>?> getByVehicule(int vehiculeId) =>
      _dao.getByVehicule(vehiculeId);

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();
}
