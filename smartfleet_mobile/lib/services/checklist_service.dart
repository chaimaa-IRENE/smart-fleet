import '../database/dao/checklist_dao.dart';
import '../database/dao/sync_dao.dart';

class ChecklistService {
  final ChecklistDao _dao = ChecklistDao();
  final SyncDao _syncDao = SyncDao();

  Future<List<Map<String, dynamic>>> getTemplates() => _dao.getTemplates();

  Future<List<Map<String, dynamic>>> getMySessions(int chauffeurId) =>
      _dao.getSessionsByChauffeur(chauffeurId);

  Future<int> startSession(
      int vehiculeId, String immat, int chauffeurId,) async {
    final sessionId = await _dao.insertSession({
      'vehiculeId': vehiculeId,
      'immatriculation': immat,
      'chauffeurId': chauffeurId,
      'conforme': 1,
      'statut': 'PENDING',
    });

    final templates = await _dao.getTemplates();
    final items = templates
        .map(
          (t) => {
            'nom': t['nom'],
            'categorie': t['categorie'],
            'obligatoire': t['obligatoire'],
            'value': null,
            'commentaire': null,
          },
        )
        .toList();

    await _dao.insertItems(sessionId, items);
    await _syncDao.addToQueue('checklist_sessions', 'INSERT', sessionId);
    return sessionId;
  }

  Future<void> updateItem(int itemId, bool value, {String? commentaire, String? defauts}) async {
    await _dao.updateItem(itemId, {
      'value': value ? 1 : 0,
      if (commentaire != null) 'commentaire': commentaire,
      if (defauts != null) 'defauts': defauts,
    });
  }

  Future<int> completeSession(
    int sessionId, {
    bool conforme = true,
    String? signature,
  }) async {
    final result = await _dao.updateSession(sessionId, {
      'conforme': conforme ? 1 : 0,
      'statut': 'COMPLETE',
      if (signature != null) 'signature': signature,
    });
    await _syncDao.addToQueue('checklist_sessions', 'COMPLETE', sessionId);
    return result;
  }

  Future<void> updateItemValue(int itemId, bool value, {String? commentaire, String? defauts}) async {
    await _dao.updateItem(itemId, {
      'value': value ? 1 : 0,
      if (commentaire != null) 'commentaire': commentaire,
      if (defauts != null) 'defauts': defauts,
    });
  }

  Future<Map<String, dynamic>?> getSession(int id) => _dao.getSession(id);

  Future<List<Map<String, dynamic>>> getSessionItems(int sessionId) =>
      _dao.getItems(sessionId);

  Future<int> markForRepair(int sessionId, String feedback) async {
    final result = await _dao.updateSession(sessionId, {
      'statut': 'REPAIRE',
      'feedback': feedback,
    });
    await _syncDao.addToQueue('checklist_sessions', 'UPDATE', sessionId);
    return result;
  }

  Future<int> validateSession(int sessionId) async {
    final result = await _dao.updateSession(sessionId, {
      'statut': 'VALIDATED',
    });
    await _syncDao.addToQueue('checklist_sessions', 'UPDATE', sessionId);
    return result;
  }

  Future<int> rejectSession(int sessionId, String feedback) async {
    final result = await _dao.updateSession(sessionId, {
      'statut': 'REJECTED',
      'feedback': feedback,
    });
    await _syncDao.addToQueue('checklist_sessions', 'UPDATE', sessionId);
    return result;
  }

  Future<List<Map<String, dynamic>>> getPendingValidation() =>
      _dao.getPendingValidation();
}
