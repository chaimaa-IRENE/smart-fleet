import '../database/dao/tracking_dao.dart';

class TrackingService {
  final TrackingDao _dao = TrackingDao();

  Future<int> updatePosition(
    String immatriculation,
    double lat,
    double lon, {
    double? vitesse,
    double? angle,
    int? ignition,
  }) async {
    return await _dao.update({
      'immatriculation': immatriculation,
      'latitude': lat,
      'longitude': lon,
      'vitesse': vitesse ?? 0,
      'angle': angle ?? 0,
      'ignition': ignition ?? 0,
      'dateTracking': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getLatest(String immatriculation) =>
      _dao.getLatest(immatriculation);

  Future<List<Map<String, dynamic>>> getAllLatest() => _dao.getAllLatest();

  Future<List<Map<String, dynamic>>> getHistory(
    String immatriculation, {
    DateTime? from,
    DateTime? to,
  }) =>
      _dao.getHistory(immatriculation, from: from, to: to);

  Future<Map<String, dynamic>> getAnalytics(String immatriculation) =>
      _dao.getAnalytics(immatriculation);
}
