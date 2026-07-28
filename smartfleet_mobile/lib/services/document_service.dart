import '../database/dao/document_dao.dart';

class DocumentVehiculeService {
  final DocumentVehiculeDao _dao = DocumentVehiculeDao();

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();
  Future<List<Map<String, dynamic>>> getByVehicule(int id) =>
      _dao.getByVehicule(id);
  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);
  Future<Map<String, dynamic>> getStats() => _dao.getStats();

  Future<List<Map<String, dynamic>>> getExpiringSoon(int days) =>
      _dao.getExpiringSoon(days);
  Future<List<Map<String, dynamic>>> getExpired() => _dao.getExpired();

  String getStatutDocument(Map<String, dynamic> doc) {
    final exp = doc['dateExpiration'] as String?;
    if (exp == null) return 'EN_ATTENTE';
    final date = DateTime.tryParse(exp);
    if (date == null) return 'EN_ATTENTE';
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff < 0) return 'EXPIRE';
    if (diff <= 30) return 'BIENTOT_EXPIRE';
    return 'VALIDE';
  }

  Future<int> create(Map<String, dynamic> data) => _dao.insert(data);
  Future<int> update(int id, Map<String, dynamic> data) =>
      _dao.update(id, data);
  Future<int> archive(int id) => _dao.archive(id);
  Future<int> delete(int id) => _dao.delete(id);
}
