import 'package:flutter/foundation.dart';
import '../services/declaration_service.dart';

class DeclarationProvider extends ChangeNotifier {
  final DeclarationService _service;
  List<Map<String, dynamic>> _declarations = [];
  Map<String, dynamic>? _selectedDeclaration;
  bool _loading = false;
  String? _error;

  DeclarationProvider(this._service);

  List<Map<String, dynamic>> get declarations => _declarations;
  Map<String, dynamic>? get selected => _selectedDeclaration;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _declarations = await _service.getAll();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMine(int chauffeurId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _declarations = await _service.getMyDeclarations(chauffeurId);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<int?> create(Map<String, dynamic> data) async {
    try {
      final id = await _service.create(data);
      data['id'] = id;
      _declarations.insert(0, data);
      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      await _service.update(id, data);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) _declarations[idx] = data;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _service.delete(id);
      _declarations.removeWhere((d) => d['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> takeCharge(
      int id, int prestataireId, String prestataireNom,) async {
    try {
      await _service.takeCharge(id, prestataireId, prestataireNom);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'PRISE_EN_CHARGE';
        _declarations[idx]['prestataireId'] = prestataireId;
        _declarations[idx]['prestataireNom'] = prestataireNom;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> startWork(int id) async {
    try {
      await _service.startWork(id);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) _declarations[idx]['statut'] = 'EN_COURS';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitForValidation(
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
    try {
      await _service.submitForValidation(
        id,
        solution: solution,
        actionsRealisees: actionsRealisees,
        piecesNecessaires: piecesNecessaires,
        contratBonCommande: contratBonCommande,
        coutReel: coutReel,
        dureeReparation: dureeReparation,
        etatReparation: etatReparation,
        dateReparation: dateReparation,
      );
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'EN_VALIDATION';
        if (solution != null) _declarations[idx]['solution'] = solution;
        if (actionsRealisees != null)
          _declarations[idx]['actionsRealisees'] = actionsRealisees;
        if (piecesNecessaires != null)
          _declarations[idx]['piecesNecessaires'] = piecesNecessaires;
        if (contratBonCommande != null)
          _declarations[idx]['contratBonCommande'] = contratBonCommande;
        if (coutReel != null) _declarations[idx]['coutReel'] = coutReel;
        if (dureeReparation != null)
          _declarations[idx]['dureeReparation'] = dureeReparation;
        if (etatReparation != null)
          _declarations[idx]['etatReparation'] = etatReparation;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markProcessed(int id, {double? coutReel}) async {
    try {
      await _service.markProcessed(id, coutReel: coutReel);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'TRAITE';
        if (coutReel != null) _declarations[idx]['coutReel'] = coutReel;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> returnDeclaration(int id, String motif) async {
    try {
      await _service.returnDeclaration(id, motif);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'RETOURNEE';
        _declarations[idx]['motifRejet'] = motif;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> refuseDeclaration(int id, String motif) async {
    try {
      await _service.refuseDeclaration(id, motif);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'REFUSE';
        _declarations[idx]['motifRejet'] = motif;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> close(int id, {double? coutReel}) async {
    try {
      await _service.closeDeclaration(id, coutReel: coutReel);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'CLOTURE';
        if (coutReel != null) _declarations[idx]['coutReel'] = coutReel;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsInProgress(int id) async {
    try {
      await _service.markAsInProgress(id);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) _declarations[idx]['statut'] = 'EN_COURS';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsValidated(int id) async {
    try {
      await _service.markAsValidated(id);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) _declarations[idx]['statut'] = 'EN_VALIDATION';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsProcessed(int id, {double? coutReel}) async {
    try {
      await _service.markAsProcessed(id, coutReel: coutReel);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'TRAITE';
        if (coutReel != null) _declarations[idx]['coutReel'] = coutReel;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reject(int id, String motif) async {
    try {
      await _service.rejectDeclaration(id, motif);
      final idx = _declarations.indexWhere((d) => d['id'] == id);
      if (idx >= 0) {
        _declarations[idx]['statut'] = 'REJETEE';
        _declarations[idx]['motifRejet'] = motif;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> getStats() => _service.getStats();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
