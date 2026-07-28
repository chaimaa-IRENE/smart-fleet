import '../database/dao/ticket_dao.dart';
import '../database/dao/audit_log_dao.dart';

class TicketMaintenanceService {
  final TicketMaintenanceDao _dao = TicketMaintenanceDao();
  final AuditLogDao _auditDao = AuditLogDao();

  Future<List<Map<String, dynamic>>> getAll({String? statut}) =>
      _dao.getAll(statut: statut);
  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);
  Future<List<Map<String, dynamic>>> getByVehicule(int id) =>
      _dao.getByVehicule(id);
  Future<Map<String, dynamic>> getStats() => _dao.getStats();
  Future<List<Map<String, dynamic>>> getInterventions(int ticketId) =>
      _dao.getInterventions(ticketId);

  Future<int> create(Map<String, dynamic> data) async {
    data['numero'] =
        'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    data['dateCreation'] = DateTime.now().toIso8601String();
    data['statut'] = 'OUVERT';
    final id = await _dao.insert(data);
    await _auditDao.log({
      'action': 'CREATE_TICKET',
      'entite': 'TICKET_MAINTENANCE',
      'entiteId': id,
      'details': data['description'],
    });
    return id;
  }

  Future<int> assigner(int id, String technicien) async {
    final result = await _dao.update(id, {
      'statut': 'AFFECTE',
      'technicien': technicien,
      'assigneA': technicien,
    });
    await _auditDao.log({
      'action': 'ASSIGNER_TICKET',
      'entite': 'TICKET_MAINTENANCE',
      'entiteId': id,
      'details': technicien,
    });
    return result;
  }

  Future<int> demarrer(int id) async {
    final result = await _dao.updateStatut(id, 'EN_COURS');
    await _auditDao.log({
      'action': 'DEMARRER_TICKET',
      'entite': 'TICKET_MAINTENANCE',
      'entiteId': id,
    });
    return result;
  }

  Future<int> terminer(int id, {double? coutReel, String? notes}) async {
    final data = <String, dynamic>{};
    if (coutReel != null) data['coutReel'] = coutReel;
    if (notes != null) data['notes'] = notes;
    if (data.isNotEmpty) await _dao.update(id, data);
    final result = await _dao.updateStatut(id, 'CLOTURE');
    await _auditDao.log({
      'action': 'TERMINER_TICKET',
      'entite': 'TICKET_MAINTENANCE',
      'entiteId': id,
    });
    return result;
  }

  Future<int> addIntervention(int ticketId, Map<String, dynamic> data) async {
    data['ticketId'] = ticketId;
    return await _dao.insertIntervention(data);
  }

  Future<int> delete(int id) => _dao.delete(id);
}
