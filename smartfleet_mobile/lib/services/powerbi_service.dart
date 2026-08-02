import '../database/dao/declaration_dao.dart';
import '../database/dao/vehicle_dao.dart';
import '../database/dao/anomalie_dao.dart';
import '../database/dao/document_dao.dart';
import '../database/dao/checkup_dao.dart';
import '../database/dao/budget_dao.dart';
import '../database/dao/ticket_dao.dart';

class PowerBiService {
  final DeclarationDao _declarationDao = DeclarationDao();
  final VehicleDao _vehicleDao = VehicleDao();
  final AnomalieDao _anomalieDao = AnomalieDao();
  final DocumentVehiculeDao _documentDao = DocumentVehiculeDao();
  final CheckupDao _checkupDao = CheckupDao();
  final BudgetDao _budgetDao = BudgetDao();
  final TicketMaintenanceDao _ticketDao = TicketMaintenanceDao();

  Future<Map<String, dynamic>> getVehicleEvolution(
    String immat, {
    String? mois1,
    String? mois2,
  }) async {
    final vehicle = await _vehicleDao.getByImmat(immat);
    final evolution =
        await _declarationDao.getEvolution(immat, mois1: mois1, mois2: mois2);
    final moisRows = await _declarationDao.getAvailableMonths(immat);

    return {
      'immatriculation': immat,
      'marque': vehicle?['marque'] ?? '',
      'modele': vehicle?['modele'] ?? '',
      'evolution': evolution,
      'moisDisponibles': moisRows.map((r) => r['mois'] as String).toList(),
    };
  }

  Future<List<String>> getAvailableMonths(String immat) async {
    final rows = await _declarationDao.getAvailableMonths(immat);
    return rows.map((r) => r['mois'] as String).toList();
  }

  Future<Map<String, dynamic>> getKpiData(
    String immat, {
    String? mois1,
    String? mois2,
  }) async {
    final evolution =
        await _declarationDao.getEvolution(immat, mois1: mois1, mois2: mois2);
    double coutTotal = 0;
    int panneCount = 0;
    double maxCout = 0;
    String topPanne = '';

    final typeCounts = <String, int>{};
    final typeCosts = <String, double>{};

    for (var row in evolution) {
      coutTotal += (row['coutTotal'] as num).toDouble();
      panneCount += row['nombrePannes'] as int;
    }

    final allDeclarations = await _declarationDao.getByVehicle(immat);
    for (var d in allDeclarations) {
      final type = d['typePanne'] as String? ?? 'AUTRE';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      typeCosts[type] =
          (typeCosts[type] ?? 0) + ((d['coutReel'] as num?)?.toDouble() ?? 0);

      if ((typeCosts[type] ?? 0) > maxCout) {
        maxCout = typeCosts[type] ?? 0;
        topPanne = type;
      }
    }

    final vehicleCount = await _vehicleDao.count();

    return {
      'coutMoyenParPanne': panneCount > 0 ? coutTotal / panneCount : 0,
      'panneParVehicule': vehicleCount > 0 ? panneCount / vehicleCount : 0,
      'dureeMoyenneReparation': 0,
      'topPanne': topPanne,
      'typeCounts': typeCounts,
      'typeCosts': typeCosts,
    };
  }

  Future<Map<String, dynamic>> getHeatmap(
    String immat, {
    String? mois,
  }) async {
    final declarations = await _declarationDao.getByVehicle(immat);
    final jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final heures =
        List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
    final valeurs = List.generate(7, (_) => List.generate(24, (_) => 0.0));

    for (var d in declarations) {
      if (mois != null) {
        final dateMois = (d['dateCreation'] as String?) ?? '';
        if (!dateMois.startsWith(mois)) continue;
      }
      try {
        final dateStr = d['dateCreation'] as String? ?? '';
        if (dateStr.length >= 16) {
          final dt = DateTime.parse(dateStr.substring(0, 16));
          final jourIdx = dt.weekday - 1;
          final heureIdx = dt.hour;
          if (jourIdx >= 0 && jourIdx < 7 && heureIdx >= 0 && heureIdx < 24) {
            valeurs[jourIdx][heureIdx] += 1;
          }
        }
      } catch (_) {}
    }

    return {
      'jours': jours,
      'heures': heures,
      'valeurs': valeurs,
    };
  }

  Future<Map<String, dynamic>> getOverview() async {
    final allDecs = await _declarationDao.getAll();
    final total = allDecs.length;
    final coutTotal = allDecs.fold<double>(
      0,
      (sum, d) => sum + ((d['coutReel'] as num?)?.toDouble() ?? 0),
    );
    final enAttente = allDecs.where((d) => d['statut'] == 'EN_ATTENTE').length;
    final enCours = allDecs
        .where((d) =>
            d['statut'] == 'PRISE_EN_CHARGE' || d['statut'] == 'EN_COURS')
        .length;
    final cloture = allDecs.where((d) => d['statut'] == 'CLOTURE').length;

    return {
      'totalDeclarations': total,
      'coutTotal': coutTotal,
      'enAttente': enAttente,
      'enCours': enCours,
      'cloture': cloture,
    };
  }

  Future<Map<String, dynamic>> getDashboardData() async {
    final vehicles = await _vehicleDao.getAll();
    final anomalies = await _anomalieDao.getAll();
    final declarations = await _declarationDao.getAll();
    final documents = await _documentDao.getAll();
    final checkups = await _checkupDao.getAll();
    final budget = await _budgetDao.getCurrent();
    final tickets = await _ticketDao.getAll();

    final now = DateTime.now();

    // ── KPIs ──
    final totalVehicules = vehicles.length;
    final enService = vehicles.where((v) => v['statut'] == 'DISPONIBLE' || v['statut'] == 'EN_SERVICE').length;
    final aArret = vehicles.where((v) => v['statut'] == 'A_ARRET' || v['statut'] == 'IMMOBILISE').length;
    final enMaintenance = vehicles.where((v) => v['statut'] == 'MAINTENANCE' || v['statut'] == 'EN_MAINTENANCE').length;
    final bloques = vehicles.where((v) => v['statut'] == 'BLOQUE').length;
    final tauxUtilisation = totalVehicules > 0 ? (enService / totalVehicules * 100) : 0;
    final anomaliesOuvertes = anomalies.where((a) => a['statut'] != 'VALIDEE' && a['statut'] != 'ANNULEE').length;
    final totalKm = vehicles.fold<double>(0, (s, v) => s + ((v['kilometrage'] as num?)?.toDouble() ?? 0));
    final consoMoyenne = totalKm > 0 ? (declarations.fold<double>(0, (s, d) => s + ((d['coutReel'] as num?)?.toDouble() ?? 0)) / totalKm * 100) : 0;
    final totalDeclarations = declarations.length;
    final totalChauffeurs = vehicles.where((v) => v['chauffeurNom'] != null && (v['chauffeurNom'] as String).isNotEmpty).length;
    final mttr = _calcMttr(declarations);
    final mtbf = _calcMtbf(declarations);
    final slaCompliance = _calcSla(declarations);
    final documentsExpires = documents.where((d) {
      final exp = d['dateExpiration'] as String?;
      if (exp == null) return false;
      final dt = DateTime.tryParse(exp);
      return dt != null && dt.isBefore(now);
    }).length;
    final documentsBientotExpire = documents.where((d) {
      final exp = d['dateExpiration'] as String?;
      if (exp == null) return false;
      final dt = DateTime.tryParse(exp);
      return dt != null && dt.difference(now).inDays <= 30 && dt.isAfter(now);
    }).length;
    final coutTotal = declarations.fold<double>(0, (s, d) => s + ((d['coutReel'] as num?)?.toDouble() ?? 0));
    final resolues = anomalies.where((a) => a['statut'] == 'REPAREE' || a['statut'] == 'VALIDEE').length;
    final tauxResolution = anomalies.length > 0 ? (resolues / anomalies.length * 100) : 0;
    final totalAnomalies = anomalies.length;

    // New KPIs
    final ticketsOuverts = tickets.where((t) => t['statut'] == 'OUVERT' || t['statut'] == 'EN_COURS').length;
    final vitesseMoyenne = vehicles.fold<double>(0, (s, v) => s + ((v['vitesseMoyenne'] as num?)?.toDouble() ?? 0));
    final vitesseMoyenneGlobal = vehicles.isNotEmpty ? vitesseMoyenne / vehicles.length : 0;

    // Checkup KPIs
    final totalCheckups = checkups.length;
    final checkupsConformes = checkups.where((c) => c['conforme'] == 1 || c['conforme'] == true).length;
    final checkupsNonConformes = checkups.where((c) => c['conforme'] == 0 || c['conforme'] == false).length;
    final txCheckupConformite = totalCheckups > 0 ? (checkupsConformes / totalCheckups * 100) : 0;
    final totalCheckups30j = checkups.where((c) {
      final dt = DateTime.tryParse((c['dateCheckup'] as String?) ?? '');
      return dt != null && dt.difference(now).inDays.abs() <= 30;
    }).length;

    // Budget KPIs
    final budgetTotal = (budget?['montantTotal'] as num?)?.toDouble() ?? 0;
    final budgetConsomme = (budget?['montantUtilise'] as num?)?.toDouble() ?? 0;
    final budgetRestant = budgetTotal - budgetConsomme;

    // Temps moyens
    final tempsMoyenReparation = _calcMttr(declarations);
    double tempsMoyenValidation = 0;
    final validees = declarations.where((d) => d['dateValidation'] != null && d['dateCreation'] != null).toList();
    if (validees.isNotEmpty) {
      double totalH = 0;
      int cnt = 0;
      for (var d in validees) {
        try {
          final debut = DateTime.parse((d['dateCreation'] as String).substring(0, 16));
          final fin = DateTime.parse((d['dateValidation'] as String).substring(0, 16));
          totalH += fin.difference(debut).inHours;
          cnt++;
        } catch (_) {}
      }
      tempsMoyenValidation = cnt > 0 ? totalH / cnt : 0;
    }

    // Time-based declarations
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final declarationsAujourdhui = declarations.where((d) {
      final dt = (d['dateCreation'] as String?) ?? '';
      return dt.startsWith(todayStr);
    }).length;
    final weekAgo = now.subtract(const Duration(days: 7));
    final declarationsCetteSemaine = declarations.where((d) {
      try {
        return DateTime.parse((d['dateCreation'] as String?).toString().substring(0, 10)).isAfter(weekAgo);
      } catch (_) {
        return false;
      }
    }).length;
    final monthAgo = now.subtract(const Duration(days: 30));
    final declarationsCeMois = declarations.where((d) {
      try {
        return DateTime.parse((d['dateCreation'] as String?).toString().substring(0, 10)).isAfter(monthAgo);
      } catch (_) {
        return false;
      }
    }).length;

    // Interventions stats
    final interventionsTerminees = declarations.where((d) => d['statut'] == 'CLOTURE' || d['statut'] == 'RESOLU').length;
    final interventionsEnCours = declarations.where((d) => d['statut'] == 'EN_COURS' || d['statut'] == 'PRISE_EN_CHARGE').length;
    final interventionsEnRetard = declarations.where((d) {
      if (d['datePrevue'] == null) return false;
      try {
        final prevue = DateTime.parse((d['datePrevue'] as String).substring(0, 16));
        return prevue.isBefore(now) && d['statut'] != 'CLOTURE' && d['statut'] != 'RESOLU';
      } catch (_) {
        return false;
      }
    }).length;

    final prestataires = declarations
        .map((d) => d['prestataireNom'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toSet();
    final totalPrestataires = prestataires.length;

    // ── Charts ──
    final anomaliesParSource = <String, int>{};
    final vehiculesParStatut = <String, int>{};
    final declarationsParStatut = <String, int>{};
    final declarationsParCriticite = <String, int>{};
    final declarationsParTypePanne = <String, int>{};
    final anomaliesParElement = <String, int>{};
    final declarationsParQualification = <String, int>{};
    final vehiculesParMarque = <String, int>{};
    final vehiculesParAgence = <String, int>{};
    final declarationsParCategorie = <String, int>{};
    final declarationsParChauffeur = <String, int>{};
    final interventionsParPrestataire = <String, int>{};
    final interventionsParStatut = <String, int>{};
    final chauffeursParVille = <String, int>{};
    final documentsParType = <String, int>{};
    final pannesParElement = <String, int>{};
    final coutParMois = <String, double>{};
    final budgetParMois = <String, double>{};
    final evolutionMensuelle = <Map<String, dynamic>>[];

    for (var a in anomalies) {
      final src = a['source'] as String? ?? 'INCONNU';
      anomaliesParSource[src] = (anomaliesParSource[src] ?? 0) + 1;
      final elem = a['element'] as String? ?? 'AUTRE';
      anomaliesParElement[elem] = (anomaliesParElement[elem] ?? 0) + 1;
    }
    for (var v in vehicles) {
      final s = v['statut'] as String? ?? 'INCONNU';
      vehiculesParStatut[s] = (vehiculesParStatut[s] ?? 0) + 1;
      final m = v['marque'] as String? ?? 'INCONNUE';
      vehiculesParMarque[m] = (vehiculesParMarque[m] ?? 0) + 1;
      final a = v['agence'] as String? ?? '';
      if (a.isNotEmpty) vehiculesParAgence[a] = (vehiculesParAgence[a] ?? 0) + 1;
      final ch = v['chauffeurNom'] as String? ?? '';
      if (ch.isNotEmpty) {
        declarationsParChauffeur[ch] = (declarationsParChauffeur[ch] ?? 0) + (declarations.where((d) => d['chauffeurNom'] == ch).length);
      }
      final ville = v['chauffeurVille'] as String? ?? '';
      if (ville.isNotEmpty) chauffeursParVille[ville] = (chauffeursParVille[ville] ?? 0) + 1;
    }
    for (var d in declarations) {
      final s = d['statut'] as String? ?? 'INCONNU';
      declarationsParStatut[s] = (declarationsParStatut[s] ?? 0) + 1;
      final c = d['criticite'] as String? ?? 'INCONNU';
      declarationsParCriticite[c] = (declarationsParCriticite[c] ?? 0) + 1;
      final t = d['typePanne'] as String? ?? 'AUTRE';
      declarationsParTypePanne[t] = (declarationsParTypePanne[t] ?? 0) + 1;
      final q = d['qualification'] as String? ?? 'INCONNU';
      declarationsParQualification[q] = (declarationsParQualification[q] ?? 0) + 1;
      final cat = d['categorie'] as String? ?? 'INCONNU';
      declarationsParCategorie[cat] = (declarationsParCategorie[cat] ?? 0) + 1;
      final prest = d['prestataireNom'] as String? ?? '';
      if (prest.isNotEmpty) interventionsParPrestataire[prest] = (interventionsParPrestataire[prest] ?? 0) + 1;
      final elem = d['elementVehicule'] as String? ?? 'AUTRE';
      pannesParElement[elem] = (pannesParElement[elem] ?? 0) + 1;
      final cout = (d['coutReel'] as num?)?.toDouble() ?? 0;
      String mois = '';
      try {
        mois = (d['dateCreation'] as String).substring(0, 7);
      } catch (_) {
        mois = 'INCONNU';
      }
      coutParMois[mois] = (coutParMois[mois] ?? 0) + cout;
    }

    // Interventions par statut is same as declarationsParStatut for maintenance context
    interventionsParStatut.addAll(declarationsParStatut);

    // Documents par type
    for (var d in documents) {
      final t = d['typeDocument'] as String? ?? 'AUTRE';
      documentsParType[t] = (documentsParType[t] ?? 0) + 1;
    }

    // Evolution mensuelle (anomalies + declarations merged by mois)
    final moisAnomalies = <String, int>{};
    for (var a in anomalies) {
      try {
        final m = (a['dateDetection'] as String).substring(0, 7);
        moisAnomalies[m] = (moisAnomalies[m] ?? 0) + 1;
      } catch (_) {}
    }
    final moisResolues = <String, int>{};
    for (var a in anomalies) {
      if (a['statut'] == 'VALIDEE' || a['statut'] == 'REPAREE') {
        try {
          final m = (a['dateReparation'] as String).substring(0, 7);
          moisResolues[m] = (moisResolues[m] ?? 0) + 1;
        } catch (_) {}
      }
    }
    final allMois = <String>{...moisAnomalies.keys, ...moisResolues.keys, ...coutParMois.keys};
    for (var m in allMois.toList()..sort()) {
      evolutionMensuelle.add({
        'mois': m,
        'anomalies': moisAnomalies[m] ?? 0,
        'resolues': moisResolues[m] ?? 0,
        'critiques': declarations.where((d) {
          try {
            return (d['dateCreation'] as String).startsWith(m) && d['criticite'] == 'CRITIQUE';
          } catch (_) {
            return false;
          }
        }).length,
        'tickets': tickets.where((t) {
          try {
            return (t['dateCreation'] as String).startsWith(m);
          } catch (_) {
            return false;
          }
        }).length,
      });
    }

    return {
      'kpis': {
        'totalVehicules': totalVehicules,
        'enService': enService,
        'aArret': aArret,
        'enMaintenance': enMaintenance,
        'bloques': bloques,
        'tauxUtilisation': tauxUtilisation,
        'anomaliesOuvertes': anomaliesOuvertes,
        'ticketsOuverts': ticketsOuverts,
        'totalKm': totalKm,
        'consoMoyenne': consoMoyenne,
        'vitesseMoyenne': vitesseMoyenneGlobal,
        'totalChauffeurs': totalChauffeurs,
        'txCheckupConformite': txCheckupConformite,
        'totalCheckups30j': totalCheckups30j,
        'mttr': mttr,
        'mtbf': mtbf,
        'slaCompliance': slaCompliance,
        'totalDeclarations': totalDeclarations,
        'totalMaintenances': totalDeclarations,
        'totalPrestataires': totalPrestataires,
        'totalInterventions': interventionsTerminees + interventionsEnCours,
        'budgetConsomme': budgetConsomme,
        'budgetRestant': budgetRestant,
        'budgetTotal': budgetTotal,
        'documentsExpires': documentsExpires,
        'documentsBientotExpire': documentsBientotExpire,
        'coutTotalMaintenance': coutTotal,
        'tauxDisponibilite': tauxUtilisation,
        'tempsMoyenReparation': tempsMoyenReparation,
        'tempsMoyenValidation': tempsMoyenValidation,
        'declarationsAujourdhui': declarationsAujourdhui,
        'declarationsCetteSemaine': declarationsCetteSemaine,
        'declarationsCeMois': declarationsCeMois,
        'interventionsAujourdhui': 0,
        'interventionsTerminees': interventionsTerminees,
        'interventionsEnCours': interventionsEnCours,
        'interventionsEnRetard': interventionsEnRetard,
        'vehiculesDisponibles': enService,
        'tauxResolution': tauxResolution,
        'totalAnomalies': totalAnomalies,
        'checkupsNonConformes': checkupsNonConformes,
      },
      'charts': {
        'anomaliesParSource': anomaliesParSource,
        'vehiculesParStatut': vehiculesParStatut,
        'declarationsParStatut': declarationsParStatut,
        'declarationsParCriticite': declarationsParCriticite,
        'declarationsParTypePanne': declarationsParTypePanne,
        'declarationsParQualification': declarationsParQualification,
        'vehiculesParMarque': vehiculesParMarque,
        'anomaliesParElement': anomaliesParElement,
        'vehiculesParAgence': vehiculesParAgence,
        'declarationsParCategorie': declarationsParCategorie,
        'evolutionMensuelle': evolutionMensuelle,
        'declarationsParChauffeur': declarationsParChauffeur,
        'interventionsParPrestataire': interventionsParPrestataire,
        'coutParMois': coutParMois,
        'budgetParMois': budgetParMois,
        'interventionsParStatut': interventionsParStatut,
        'chauffeursParVille': chauffeursParVille,
        'documentsParType': documentsParType,
        'pannesParElement': pannesParElement,
      },
    };
  }

  double _calcMttr(List<Map<String, dynamic>> declarations) {
    final resolues = declarations.where((d) =>
        d['dateReparation'] != null && d['dateCreation'] != null);
    if (resolues.isEmpty) return 0;
    double totalHours = 0;
    int count = 0;
    for (var d in resolues) {
      try {
        final debut = DateTime.parse((d['dateCreation'] as String).substring(0, 16));
        final fin = DateTime.parse((d['dateReparation'] as String).substring(0, 16));
        totalHours += fin.difference(debut).inHours;
        count++;
      } catch (_) {}
    }
    return count > 0 ? totalHours / count : 0;
  }

  double _calcMtbf(List<Map<String, dynamic>> declarations) {
    if (declarations.length < 2) return 0;
    final dates = declarations
        .map((d) {
          try {
            return DateTime.parse((d['dateCreation'] as String).substring(0, 16));
          } catch (_) {
            return null;
          }
        })
        .where((d) => d != null)
        .map((d) => d!)
        .toList()
      ..sort();
    if (dates.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < dates.length; i++) {
      total += dates[i].difference(dates[i - 1]).inHours;
    }
    return total / (dates.length - 1);
  }

  double _calcSla(List<Map<String, dynamic>> declarations) {
    final withSla = declarations.where((d) => d['sla'] != null);
    if (withSla.isEmpty) return 0;
    final respected = withSla.where((d) {
      final sla = (d['sla'] as num).toInt();
      final duree = (d['dureeIntervention'] as num?)?.toDouble() ?? 0;
      return duree <= sla;
    }).length;
    return (respected / withSla.length) * 100;
  }
}
