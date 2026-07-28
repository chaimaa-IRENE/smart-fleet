import '../database/dao/declaration_dao.dart';
import '../database/dao/budget_dao.dart';
import '../database/dao/sync_dao.dart';

class DeclarationService {
  final DeclarationDao _dao = DeclarationDao();
  final BudgetDao _budgetDao = BudgetDao();
  final SyncDao _syncDao = SyncDao();

  Future<List<Map<String, dynamic>>> getAll({String? statut}) =>
      _dao.getAll(statut: statut);

  Future<List<Map<String, dynamic>>> getMyDeclarations(int chauffeurId) =>
      _dao.getByChauffeur(chauffeurId);

  Future<List<Map<String, dynamic>>> getByPrestataire(int prestataireId) =>
      _dao.getByPrestataire(prestataireId);

  Future<List<Map<String, dynamic>>> getByVehicle(String immat) =>
      _dao.getByVehicle(immat);

  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);

  Future<int> create(Map<String, dynamic> data) async {
    if (data['numeroDemande'] == null || (data['numeroDemande'] as String).isEmpty) {
      final year = DateTime.now().year.toString();
      final all = await _dao.getAll();
      final count = all.length + 1;
      data['numeroDemande'] = 'INC-$year-${count.toString().padLeft(6, '0')}';
    }
    final id = await _dao.insert(data);
    await _syncDao.addToQueue('declarations', 'INSERT', id, payload: data);
    return id;
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final result = await _dao.update(id, data);
    await _syncDao.addToQueue('declarations', 'UPDATE', id, payload: data);
    return result;
  }

  Future<int> updateStatus(
    int id,
    String statut, {
    String? dateCloture,
    double? coutReel,
  }) async {
    final result = await _dao.updateStatus(
      id,
      statut,
      dateCloture: dateCloture,
      coutReel: coutReel,
    );
    await _syncDao.addToQueue(
      'declarations',
      'STATUS_UPDATE',
      id,
      payload: {
        'statut': statut,
        if (dateCloture != null) 'dateCloture': dateCloture,
        if (coutReel != null) 'coutReel': coutReel,
      },
    );
    return result;
  }

  Future<int> delete(int id) async {
    final result = await _dao.delete(id);
    await _syncDao.addToQueue('declarations', 'DELETE', id);
    return result;
  }

  Future<int> takeCharge(
      int id, int prestataireId, String prestataireNom,) async {
    return await _dao.update(id, {
      'statut': 'PRISE_EN_CHARGE',
      'prestataireId': prestataireId,
      'prestataireNom': prestataireNom,
    });
  }

  Future<int> markAsInProgress(int id) async {
    return await _dao.updateStatus(id, 'EN_COURS');
  }

  Future<int> markAsValidated(int id) async {
    return await _dao.updateStatus(id, 'EN_VALIDATION');
  }

  Future<int> markAsProcessed(int id, {double? coutReel}) async {
    final result = await _dao.updateStatus(id, 'TRAITE', coutReel: coutReel);
    await _syncDao.addToQueue('declarations', 'STATUS_UPDATE', id,
        payload: {'statut': 'TRAITE', 'coutReel': coutReel},);
    return result;
  }

  Future<int> startWork(int id) async {
    return await _dao.updateStatus(id, 'EN_COURS');
  }

  Future<int> submitForValidation(
    int id, {
    String? solution,
    String? actionsRealisees,
    String? piecesNecessaires,
    String? contratBonCommande,
    double? coutReel,
    int? dureeReparation,
    String? etatReparation,
    String? dateReparation,
  }) async {
    return await _dao.update(id, {
      'statut': 'EN_VALIDATION',
      if (solution != null) 'solution': solution,
      if (actionsRealisees != null) 'actionsRealisees': actionsRealisees,
      if (piecesNecessaires != null) 'piecesNecessaires': piecesNecessaires,
      if (contratBonCommande != null) 'contratBonCommande': contratBonCommande,
      if (coutReel != null) 'coutReel': coutReel,
      if (dureeReparation != null) 'dureeReparation': dureeReparation,
      if (etatReparation != null) 'etat': etatReparation,
      if (dateReparation != null) 'dateReparation': dateReparation,
    });
  }

  Future<int> markProcessed(int id, {double? coutReel}) async {
    final data = <String, dynamic>{'statut': 'TRAITE'};
    if (coutReel != null) data['coutReel'] = coutReel;
    return await _dao.update(id, data);
  }

  Future<int> returnDeclaration(int id, String motif) async {
    final result =
        await _dao.update(id, {'statut': 'RETOURNEE', 'motifRejet': motif});
    await _syncDao.addToQueue('declarations', 'STATUS_UPDATE', id,
        payload: {'statut': 'RETOURNEE', 'motifRejet': motif},);
    return result;
  }

  Future<int> rejectDeclaration(int id, String motif) async {
    final result = await _dao.update(id, {
      'statut': 'REJETEE',
      'motifRejet': motif,
      'dateCloture': DateTime.now().toIso8601String(),
    });
    await _syncDao.addToQueue('declarations', 'STATUS_UPDATE', id,
        payload: {'statut': 'REJETEE', 'motifRejet': motif},);
    return result;
  }

  Future<int> refuseDeclaration(int id, String motif) async {
    return await _dao.update(id, {
      'statut': 'REFUSE',
      'motifRejet': motif,
      'dateCloture': DateTime.now().toIso8601String(),
    });
  }

  Future<int> closeDeclaration(
    int id, {
    double? coutReel,
  }) async {
    final result = await _dao.updateStatus(
      id,
      'CLOTURE',
      dateCloture: DateTime.now().toIso8601String(),
      coutReel: coutReel,
    );

    final currentBudget = await _budgetDao.getCurrent();
    if (currentBudget != null) {
      await _budgetDao.recalculerUtilisation(currentBudget['id'] as int);
    }
    return result;
  }

  Future<Map<String, dynamic>> getStats() => _dao.getStats();

  Future<List<Map<String, dynamic>>> getEvolution(
    String immat, {
    String? mois1,
    String? mois2,
  }) =>
      _dao.getEvolution(immat, mois1: mois1, mois2: mois2);

  Future<List<String>> getAvailableMonths(String immat) async {
    final rows = await _dao.getAvailableMonths(immat);
    return rows.map((r) => r['mois'] as String).toList();
  }
}
