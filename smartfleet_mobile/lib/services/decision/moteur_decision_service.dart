import '../../database/dao/vehicle_dao.dart';
import '../../database/dao/document_dao.dart';
import '../../database/dao/ticket_dao.dart';
import '../../database/dao/checkup_dao.dart';
import '../../database/dao/checklist_dao.dart';
import '../../database/dao/blocking_dao.dart';
import '../../database/dao/alert_dao.dart';
import '../../database/dao/audit_log_dao.dart';

class MoteurDecisionService {
  final VehicleDao _vehicleDao = VehicleDao();
  final DocumentVehiculeDao _docDao = DocumentVehiculeDao();
  final TicketMaintenanceDao _ticketDao = TicketMaintenanceDao();
  final CheckupDao _checkupDao = CheckupDao();
  final ChecklistDao _checklistDao = ChecklistDao();
  final BlockingDao _blockingDao = BlockingDao();
  final FleetAlertDao _alertDao = FleetAlertDao();
  final AuditLogDao _auditDao = AuditLogDao();

  Future<Map<String, dynamic>> verifierConformite(
    int vehiculeId,
    int chauffeurId,
  ) async {
    final result = <String, dynamic>{
      'vehiculeId': vehiculeId,
      'chauffeurId': chauffeurId,
      'conforme': true,
      'blocages': <Map<String, dynamic>>[],
      'alertes': <String>[],
      'niveauBlocage': 'AUCUN',
    };

    final blocages = result['blocages'] as List<Map<String, dynamic>>;
    final alertes = result['alertes'] as List<String>;

    final docs = await _docDao.getByVehicule(vehiculeId);
    final expiredDocs = docs.where((d) {
      final exp = d['dateExpiration'] as String?;
      if (exp == null) return false;
      return DateTime.tryParse(exp)?.isBefore(DateTime.now()) ?? false;
    }).toList();
    if (expiredDocs.isNotEmpty) {
      for (var d in expiredDocs) {
        blocages.add({
          'type': 'DOCUMENT_EXPIRE',
          'detail': d['typeDocument'],
          'niveau': 'IMMEDIAT',
        });
        alertes.add('Document expiré: ${d['typeDocument']}');
      }
      result['niveauBlocage'] = 'IMMEDIAT';
      result['conforme'] = false;
    }

    final expiringSoon = await _docDao.getExpiringSoon(30);
    final vehicleExpiring =
        expiringSoon.where((d) => d['vehiculeId'] == vehiculeId).toList();
    for (var d in vehicleExpiring) {
      alertes.add('Document bientôt expiré: ${d['typeDocument']}');
      if (result['niveauBlocage'] != 'IMMEDIAT') {
        result['niveauBlocage'] = 'VALIDATION_RS';
        result['conforme'] = false;
      }
    }

    final tickets = await _ticketDao.getByVehicule(vehiculeId);
    final openTickets = tickets
        .where(
          (t) => t['statut'] == 'OUVERT' || t['statut'] == 'EN_COURS',
        )
        .toList();
    if (openTickets.isNotEmpty) {
      for (var t in openTickets) {
        blocages.add({
          'type': 'TICKET_MAINTENANCE',
          'detail': t['description'] ?? t['typePanne'],
          'niveau': t['priorite'] == 'URGENT' ? 'IMMEDIAT' : 'VALIDATION_RS',
        });
        alertes.add('Ticket maintenance ouvert: ${t['numero']}');
      }
      if (openTickets.any((t) => t['priorite'] == 'URGENT')) {
        result['niveauBlocage'] = 'IMMEDIAT';
      } else if (result['niveauBlocage'] != 'IMMEDIAT') {
        result['niveauBlocage'] = 'VALIDATION_RS';
      }
      result['conforme'] = false;
    }

    final lastCheckup = await _checkupDao.getLatestByVehicule(vehiculeId);
    final lastSession = await _checklistDao.getLatestCompleteByVehicule(vehiculeId);

    DateTime? latestDate;
    bool latestConforme = true;

    if (lastCheckup != null) {
      final d = DateTime.tryParse(lastCheckup['dateCheckup'] as String? ?? '');
      if (d != null && (latestDate == null || d.isAfter(latestDate))) {
        latestDate = d;
        latestConforme = lastCheckup['conforme'] == 1;
      }
    }
    if (lastSession != null) {
      final d = DateTime.tryParse(lastSession['date'] as String? ?? '');
      if (d != null && (latestDate == null || d.isAfter(latestDate))) {
        latestDate = d;
        latestConforme = lastSession['conforme'] == 1;
      }
    }

    if (latestDate != null) {
      if (!latestConforme) {
        blocages.add({
          'type': 'CHECKUP_NON_CONFORME',
          'detail': 'Dernier checkup non conforme',
          'niveau': 'IMMEDIAT',
        });
        alertes.add('Dernier checkup non conforme');
        result['niveauBlocage'] = 'IMMEDIAT';
        result['conforme'] = false;
      }
      final daysSince = DateTime.now().difference(latestDate).inDays;
      if (daysSince > 7) {
        alertes.add('Aucun checkup depuis $daysSince jours');
        if (result['niveauBlocage'] != 'IMMEDIAT') {
          result['niveauBlocage'] = 'VALIDATION_RS';
          result['conforme'] = false;
        }
      }
    } else {
      alertes.add('Aucun checkup trouvé pour ce véhicule');
      result['niveauBlocage'] = 'VALIDATION_RS';
      result['conforme'] = false;
    }

    final activeBlocking = await _blockingDao.getActiveByVehicule(vehiculeId);
    if (activeBlocking != null) {
      result['niveauBlocage'] = 'IMMEDIAT';
      result['conforme'] = false;
      blocages.add({
        'type': 'BLOCAGE_MANUEL',
        'detail': activeBlocking['raison'],
        'niveau': 'IMMEDIAT',
      });
      alertes.add('Véhicule bloqué: ${activeBlocking['raison']}');
    }

    if (result['niveauBlocage'] == 'IMMEDIAT' && result['conforme'] == false) {
      await _blockingDao.block({
        'vehiculeId': vehiculeId,
        'immatriculation':
            (await _vehicleDao.getById(vehiculeId))?['immatriculation'] ?? '',
        'raison': 'Blocage automatique - Non conforme',
        'niveau': 'IMMEDIAT',
        'bloquePar': chauffeurId,
      });
      await _alertDao.insert({
        'vehiculeId': vehiculeId,
        'type': 'NON_CONFORMITE',
        'criticite': 'CRITIQUE',
        'message': 'Véhicule bloqué automatiquement par le moteur de décision',
        'statut': 'ACTIVE',
      });
    }

    await _auditDao.log({
      'userId': chauffeurId,
      'action': 'VERIFICATION_CONFORMITE',
      'entite': 'VEHICULE',
      'entiteId': vehiculeId,
      'details':
          'Conforme: ${result['conforme']}, Niveau: ${result['niveauBlocage']}',
    });

    return result;
  }
}
