import '../../services/powerbi_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/declaration_service.dart';
import '../../services/user_service.dart';
import '../../services/alert_service.dart';
import '../../services/document_service.dart';

class VehicleRow {
  final int id;
  final String immatriculation;
  final String numeroOrdre;
  final String marque;
  final String modele;
  final String type;
  final double annee;
  final double kilometrage;
  final String statut;
  final String agence;
  final String chauffeurNom;
  final String carburant;
  final bool conforme;
  int anomalies;
  int checkups;
  int tickets;
  int documents;
  int documentsValides;
  double scoreIVMS;

  VehicleRow({
    required this.id,
    required this.immatriculation,
    required this.numeroOrdre,
    required this.marque,
    required this.modele,
    required this.type,
    required this.annee,
    required this.kilometrage,
    required this.statut,
    required this.agence,
    required this.chauffeurNom,
    required this.carburant,
    required this.conforme,
    this.anomalies = 0,
    this.checkups = 0,
    this.tickets = 0,
    this.documents = 0,
    this.documentsValides = 0,
    this.scoreIVMS = 0,
  });
}

class DeclarationRow {
  final int id;
  final String numeroDemande;
  final String vehicule;
  final String chauffeur;
  final String typePanne;
  final String criticite;
  final String statut;
  final String qualification;
  final String element;
  final String categorie;
  final String date;
  final double cout;
  final double sla;
  final String description;

  DeclarationRow({
    required this.id,
    required this.numeroDemande,
    required this.vehicule,
    required this.chauffeur,
    required this.typePanne,
    required this.criticite,
    required this.statut,
    required this.qualification,
    required this.element,
    required this.categorie,
    required this.date,
    required this.cout,
    required this.sla,
    required this.description,
  });
}

class DriverRow {
  final String nom;
  final String matricule;
  final String email;
  final String phone;
  final String ville;
  final String branchCode;
  final int anomalies;
  final int checkups;
  final int checkupsOK;
  final int tauxConformite;
  final int tauxResolution;
  final int departs;
  final int presences;
  final int score;
  final List<String> vehicules;
  final int interventions;
  final double coutTotal;

  DriverRow({
    required this.nom,
    required this.matricule,
    required this.email,
    required this.phone,
    required this.ville,
    required this.branchCode,
    required this.anomalies,
    required this.checkups,
    required this.checkupsOK,
    required this.tauxConformite,
    required this.tauxResolution,
    required this.departs,
    required this.presences,
    required this.score,
    required this.vehicules,
    required this.interventions,
    required this.coutTotal,
  });
}

class DocumentRow {
  final String vehicule;
  final String type;
  final String dateExpiration;
  final int joursRestants;

  DocumentRow({
    required this.vehicule,
    required this.type,
    required this.dateExpiration,
    required this.joursRestants,
  });
}

class AlertRow {
  final String type;
  final String message;
  final String severite;
  final String immatriculation;

  AlertRow({
    required this.type,
    required this.message,
    required this.severite,
    required this.immatriculation,
  });
}

class DashboardData {
  final Map<String, dynamic> kpis;
  final Map<String, dynamic> charts;
  final List<VehicleRow> vehicles;
  final List<DeclarationRow> declarations;
  final List<DriverRow> drivers;
  final List<DocumentRow> documents;
  final List<AlertRow> alerts;
  final List<Map<String, dynamic>> budgetAnalysis;
  final Map<String, dynamic>? activeBudget;
  final Map<String, dynamic>? documentStats;
  final List<Map<String, dynamic>> aiInsights;
  final Map<String, dynamic> filterOptions;

  DashboardData({
    required this.kpis,
    required this.charts,
    required this.vehicles,
    required this.declarations,
    required this.drivers,
    required this.documents,
    required this.alerts,
    required this.budgetAnalysis,
    required this.activeBudget,
    required this.documentStats,
    required this.aiInsights,
    required this.filterOptions,
  });

  DashboardData copyWith({
    Map<String, dynamic>? kpis,
    Map<String, dynamic>? charts,
    List<VehicleRow>? vehicles,
    List<DeclarationRow>? declarations,
    List<DriverRow>? drivers,
  }) {
    return DashboardData(
      kpis: kpis ?? this.kpis,
      charts: charts ?? this.charts,
      vehicles: vehicles ?? this.vehicles,
      declarations: declarations ?? this.declarations,
      drivers: drivers ?? this.drivers,
      documents: documents,
      alerts: alerts,
      budgetAnalysis: budgetAnalysis,
      activeBudget: activeBudget,
      documentStats: documentStats,
      aiInsights: aiInsights,
      filterOptions: filterOptions,
    );
  }
}

double safeNum(dynamic v, [double d = 0]) {
  if (v == null || v == '' ) return d;
  final n = v is num ? v.toDouble() : double.tryParse(v.toString());
  return (n == null || n.isNaN) ? d : n;
}

int safeInt(dynamic v, [int d = 0]) {
  if (v == null || v == '') return d;
  final n = v is num ? v.toInt() : int.tryParse(v.toString());
  return n == null ? d : n;
}

String safeStr(dynamic v, [String d = '']) {
  if (v == null) return d;
  return v.toString();
}

String todayStr() {
  final n = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

String reverseName(String n) {
  final parts = n.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.length == 2 ? '${parts[1]} ${parts[0]}' : n;
}

bool namesMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  return a.toLowerCase() == b.toLowerCase() ||
      a.toLowerCase() == reverseName(b).toLowerCase();
}

List<VehicleRow> buildVehicles(List<Map<String, dynamic>> raw) {
  return raw.map((v) {
    return VehicleRow(
      id: safeInt(v['id']),
      immatriculation: safeStr(v['immatriculation']),
      numeroOrdre: safeStr(v['truckNumber'] ?? v['vehicleId'] ?? ''),
      marque: safeStr(v['marque']),
      modele: safeStr(v['modele']),
      type: safeStr(v['type']),
      annee: safeNum(v['annee']),
      kilometrage: safeNum(v['kilometrage']),
      statut: safeStr(v['statut'], 'INCONNU'),
      agence: safeStr(v['agence']),
      chauffeurNom: safeStr(v['chauffeurNom']),
      carburant: safeStr(v['carburant']),
      conforme: (v['conforme'] ?? 1) == 1,
    );
  }).toList();
}

List<DeclarationRow> buildDeclarations(List<Map<String, dynamic>> raw) {
  return raw.map((d) {
    return DeclarationRow(
      id: safeInt(d['id']),
      numeroDemande: safeStr(d['numeroDemande'] ?? d['numeroDeclaration'] ?? ''),
      vehicule: safeStr(d['immatriculation'] ?? d['vehiculeImmatriculation'] ?? ''),
      chauffeur: safeStr(d['chauffeurNom'] ?? ''),
      typePanne: safeStr(d['typePanne']),
      criticite: safeStr(d['criticite']),
      statut: safeStr(d['statut']),
      qualification: safeStr(d['qualification']),
      element: safeStr(d['elementVehicule'] ?? d['element'] ?? ''),
      categorie: safeStr(d['categorie']),
      date: safeStr(d['dateCreation'] ?? d['dateDeclaration'] ?? ''),
      cout: safeNum(d['coutReel'] ?? d['coutEstime'] ?? d['coutProbleme']),
      sla: safeNum(d['sla']),
      description: safeStr(d['description']),
    );
  }).toList();
}

List<DriverRow> buildDrivers(
  List<Map<String, dynamic>> users,
  List<VehicleRow> vehicles,
  List<DeclarationRow> declarations,
) {
  final chauffeurs = users.where((u) =>
      u['role'] == 'CHAUFFEUR' ||
      (safeStr(u['roleCode']) == 'CHAUFFEUR') ||
      (safeStr(u['personCode']).startsWith('CHF'))).toList();
  if (chauffeurs.isEmpty) return [];

  return chauffeurs.map((u) {
    final userId = safeInt(u['id']);
    final nom = '${safeStr(u['nom'])} ${safeStr(u['prenom'])}'.trim().isNotEmpty
        ? '${safeStr(u['nom'])} ${safeStr(u['prenom'])}'.trim()
        : safeStr(u['username']);
    final personCode = safeStr(u['matricule'] ?? u['personCode'] ?? '');
    final vList = vehicles.where((v) => v.chauffeurNom == nom).toList();
    final dList = declarations.where((d) => namesMatch(d.chauffeur, nom)).toList();
    final decsOuvertes = dList.where((d) =>
        d.statut != 'CLOTURE' && d.statut != 'RESOLU' && d.statut != 'ANNULE').length;
    final decsResolues = dList.where((d) =>
        d.statut == 'CLOTURE' || d.statut == 'RESOLU').length;

    final totalDecs = dList.length;
    final resolved = decsResolues;
    final checkups = 0;
    final checkupsOK = 0;

    final tauxConf = checkups > 0 ? ((checkupsOK / checkups) * 100).round() : 0;
    final tauxResoResolved = totalDecs > 0 ? ((resolved / totalDecs) * 100).round() : 0;
    final conso = totalDecs > 0 ? (dList.fold<double>(0, (s, d) => s + d.cout) / totalDecs).round() : 0;

    var score = 0;
    if (totalDecs > 0 || checkups > 0) {
      final compConf = tauxConf * 0.30;
      final compAno = totalDecs > 0 ? (100 - (decsOuvertes / totalDecs) * 100).clamp(0, 100) * 0.25 : 0.0;
      final compInc = totalDecs > 0 ? (resolved / totalDecs) * 100 * 0.20 : 0.0;
      final compPont = 0.0;
      final compConso = conso > 0 ? (100 - (conso / 1000) * 10).clamp(0, 100) * 0.10 : 0.0;
      score = (compConf + compAno + compInc + compPont + compConso).round();
    }

    return DriverRow(
      nom: nom,
      matricule: personCode,
      email: safeStr(u['email']),
      phone: safeStr(u['telephone'] ?? u['phone'] ?? u['cellularPhone']),
      ville: safeStr(u['branchCode'] ?? u['ville'] ?? ''),
      branchCode: safeStr(u['branchCode']),
      anomalies: totalDecs,
      checkups: checkups,
      checkupsOK: checkupsOK,
      tauxConformite: tauxConf,
      tauxResolution: tauxResoResolved,
      departs: 0,
      presences: 0,
      score: score,
      vehicules: vList.map((vv) => vv.immatriculation).toList(),
      interventions: 0,
      coutTotal: dList.fold<double>(0, (s, d) => s + d.cout),
    );
  }).toList();
}

List<VehicleRow> computeVehicleMetrics(
  List<VehicleRow> vehicles,
  List<DeclarationRow> declarations,
) {
  final decByVeh = <String, List<DeclarationRow>>{};
  for (final d in declarations) {
    final key = d.vehicule;
    if (key.isEmpty) continue;
    decByVeh.putIfAbsent(key, () => []).add(d);
  }

  return vehicles.map((v) {
    final vDecs = decByVeh[v.immatriculation] ?? [];
    final totalDecs = vDecs.length;
    final ouvertes = vDecs.where((d) =>
        d.statut != 'CLOTURE' && d.statut != 'RESOLU' && d.statut != 'ANNULE').length;
    final resolues = vDecs.where((d) =>
        d.statut == 'CLOTURE' || d.statut == 'RESOLU').length;
    final coutTotal = vDecs.fold<double>(0, (s, d) => s + d.cout);
    final txReso = totalDecs > 0 ? resolues / totalDecs : 0.0;
    final kbKm = v.kilometrage > 0
        ? (totalDecs * 1000 / v.kilometrage).clamp(0.0, 1.0)
        : 0.5;

    var ivms = 100.0;
    ivms -= (1 - txReso) * 40;
    ivms -= (kbKm * 30).clamp(0.0, 30.0);
    final costPerDec = totalDecs > 0 ? coutTotal / totalDecs : 0.0;
    ivms -= ((costPerDec / 5000) * 20).clamp(0.0, 20.0);
    ivms -= ouvertes * 5;
    ivms = ivms.clamp(0.0, 100.0).roundToDouble();

    return VehicleRow(
      id: v.id,
      immatriculation: v.immatriculation,
      numeroOrdre: v.numeroOrdre,
      marque: v.marque,
      modele: v.modele,
      type: v.type,
      annee: v.annee,
      kilometrage: v.kilometrage,
      statut: v.statut,
      agence: v.agence,
      chauffeurNom: v.chauffeurNom,
      carburant: v.carburant,
      conforme: v.conforme,
      anomalies: totalDecs,
      checkups: v.checkups,
      tickets: v.tickets,
      documents: v.documents,
      documentsValides: v.documentsValides,
      scoreIVMS: ivms,
    );
  }).toList();
}

List<Map<String, dynamic>> buildEvolutionMensuelle(List<DeclarationRow> declarations) {
  final groups = <String, Map<String, dynamic>>{};
  for (final d in declarations) {
    if (d.date.isEmpty) continue;
    final mois = d.date.length >= 7 ? d.date.substring(0, 7) : d.date;
    final g = groups.putIfAbsent(mois, () => {
      'mois': mois,
      'anomalies': 0,
      'resolues': 0,
      'critiques': 0,
      'checkups': 0,
      'checkupsOK': 0,
      'tickets': 0,
    });
    g['anomalies'] = (g['anomalies'] as int) + 1;
    if (d.statut == 'CLOTURE' || d.statut == 'RESOLU') {
      g['resolues'] = (g['resolues'] as int) + 1;
    }
    if (d.criticite == 'CRITIQUE' || d.criticite == 'BLOQUANT') {
      g['critiques'] = (g['critiques'] as int) + 1;
    }
  }
  final keys = groups.keys.toList()..sort();
  return keys.map((k) => groups[k]!).toList();
}

List<String> uniqSorted(List<String> arr) {
  final m = <String, String>{};
  for (final x in arr) {
    m[x] = x;
  }
  final list = m.values.toList()..sort();
  return list;
}

class PowerBiDataLoader {
  final PowerBiService _powerbi = PowerBiService();
  final VehicleService _vehicleService = VehicleService();
  final DeclarationService _declarationService = DeclarationService();
  final UserService _userService = UserService();
  final FleetAlertService _alertService = FleetAlertService();
  final DocumentVehiculeService _documentService = DocumentVehiculeService();

  Future<DashboardData> load() async {
    final serviceData = await _powerbi.getDashboardData();
    final rawVehicles = await _vehicleService.getAll();
    final rawDeclarations = await _declarationService.getAll();
    final rawUsers = await _userService.getAll();
    final rawAlerts = await _alertService.getActive();
    final rawDocuments = await _documentService.getAll();

    final kpis = (serviceData['kpis'] as Map<String, dynamic>?) ?? {};
    var charts = (serviceData['charts'] as Map<String, dynamic>?) ?? {};

    final documents = rawDocuments.map((d) {
      final exp = safeStr(d['dateExpiration'], '');
      int jrs = 0;
      if (exp.isNotEmpty) {
        try {
          jrs = DateTime.parse(exp.substring(0, 10))
              .difference(DateTime.now())
              .inDays;
        } catch (_) {
          jrs = 0;
        }
      }
      return DocumentRow(
        vehicule: safeStr(d['immatriculation']),
        type: safeStr(d['typeDocument']),
        dateExpiration: exp,
        joursRestants: jrs,
      );
    }).toList();

    final vehicles = buildVehicles(rawVehicles);
    final declarations = buildDeclarations(rawDeclarations);
    final vehiclesMetrics = computeVehicleMetrics(vehicles, declarations);

    for (final v in vehiclesMetrics) {
      v.documents = documents.where((d) => d.vehicule == v.immatriculation).length;
      v.documentsValides = documents.where((d) =>
          d.vehicule == v.immatriculation && d.joursRestants >= 0).length;
    }

    final drivers = buildDrivers(rawUsers, vehiclesMetrics, declarations);

    final alerts = rawAlerts.map((a) {
      final c = safeStr(a['criticite'], 'MOYENNE');
      final sev = (c == 'CRITIQUE' || c == 'BLOQUANT' || c == 'HAUTE')
          ? 'HAUTE'
          : (c == 'MAJEURE' || c == 'MOYENNE') ? 'MOYENNE' : 'BASSE';
      return AlertRow(
        type: safeStr(a['type']),
        message: safeStr(a['message']),
        severite: sev,
        immatriculation: safeStr(a['immatriculation']),
      );
    }).toList();

    var evolution = buildEvolutionMensuelle(declarations);
    final serviceEvolution = (charts['evolutionMensuelle'] as List?) ?? [];
    final evoKeys = evolution.map((e) => e['mois']).toSet();
    for (final e in serviceEvolution) {
      if (e is Map<String, dynamic> && !evoKeys.contains(e['mois'])) {
        evolution.add({
          'mois': e['mois'],
          'anomalies': safeInt(e['anomalies']),
          'resolues': safeInt(e['resolues']),
          'critiques': safeInt(e['critiques']),
          'checkups': safeInt(e['checkups']),
          'checkupsOK': safeInt(e['checkupsOK']),
          'tickets': safeInt(e['tickets']),
        });
      }
    }
    evolution.sort((a, b) => (a['mois'] as String).compareTo(b['mois'] as String));
    charts = {...charts, 'evolutionMensuelle': evolution};

    final documentStats = <String, dynamic>{
      'valides': documents.where((d) => d.joursRestants > 30).length,
      'expires': documents.where((d) => d.joursRestants < 0).length,
      'bientotExpires': documents.where((d) => d.joursRestants >= 0 && d.joursRestants <= 30).length,
    };

    final dList = rawVehicles;
    final filterOptions = <String, dynamic>{
      'sites': uniqSorted(dList.map((v) => safeStr(v['agence'])).where((s) => s.isNotEmpty).toList()),
      'regions': <String>[],
      'vehicles': dList.where((o) => safeStr(o['immatriculation']).isNotEmpty)
          .map((v) => {'immatriculation': safeStr(v['immatriculation']), 'marque': safeStr(v['marque'])}).toList(),
      'status': uniqSorted(dList.map((v) => safeStr(v['statut'])).where((s) => s.isNotEmpty).toList()),
      'drivers': drivers.map((d) => d.nom).where((n) => n.isNotEmpty).toList(),
      'villes': uniqSorted(drivers.map((d) => d.ville).where((s) => s.isNotEmpty).toList()),
      'prestataires': uniqSorted(rawDeclarations.map((d) => safeStr(d['prestataireNom'])).where((s) => s.isNotEmpty).toList()),
      'typesPanne': uniqSorted(rawDeclarations.map((d) => safeStr(d['typePanne'])).where((s) => s.isNotEmpty).toList()),
      'criticites': uniqSorted(rawDeclarations.map((d) => safeStr(d['criticite'])).where((s) => s.isNotEmpty).toList()),
      'annees': uniqSorted(rawDeclarations.map((d) {
        final dt = safeStr(d['dateCreation'] ?? d['dateDeclaration'] ?? '');
        return dt.length >= 4 ? dt.substring(0, 4) : '';
      }).where((s) => s.isNotEmpty).toList()),
      'mois': ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'],
    };

    return DashboardData(
      kpis: kpis,
      charts: charts,
      vehicles: vehiclesMetrics,
      declarations: declarations,
      drivers: drivers,
      documents: documents,
      alerts: alerts,
      budgetAnalysis: <Map<String, dynamic>>[],
      activeBudget: null,
      documentStats: documentStats,
      aiInsights: <Map<String, dynamic>>[],
      filterOptions: filterOptions,
    );
  }
}

DashboardData filterDashboardData(DashboardData data, Map<String, dynamic> f) {
  final hasAnyFilter = (f['site'] as String? ?? '').isNotEmpty ||
      (f['vehicle'] as String? ?? '').isNotEmpty ||
      (f['driver'] as String? ?? '').isNotEmpty ||
      (f['status'] as String? ?? '').isNotEmpty ||
      (f['criticite'] as String? ?? '').isNotEmpty ||
      (f['typePanne'] as String? ?? '').isNotEmpty ||
      (f['prestataire'] as String? ?? '').isNotEmpty ||
      (f['ville'] as String? ?? '').isNotEmpty ||
      (f['annee'] as String? ?? '').isNotEmpty ||
      (f['mois'] as String? ?? '').isNotEmpty ||
      (f['period'] as String? ?? '').isNotEmpty;
  if (!hasAnyFilter) return data;

  final site = f['site'] as String? ?? '';
  final vehicle = f['vehicle'] as String? ?? '';
  final driver = f['driver'] as String? ?? '';
  final status = f['status'] as String? ?? '';
  final criticite = f['criticite'] as String? ?? '';
  final typePanne = f['typePanne'] as String? ?? '';
  final prestataire = f['prestataire'] as String? ?? '';
  final ville = f['ville'] as String? ?? '';
  final annee = f['annee'] as String? ?? '';
  final mois = f['mois'] as String? ?? '';
  final period = f['period'] as String? ?? '';

  var filteredVehicles = data.vehicles;
  if (site.isNotEmpty) {
    filteredVehicles = filteredVehicles.where((v) => v.agence == site).toList();
  }
  if (vehicle.isNotEmpty) {
    filteredVehicles = filteredVehicles.where((v) => v.immatriculation == vehicle).toList();
  }
  if (status.isNotEmpty) {
    filteredVehicles = filteredVehicles.where((v) => v.statut == status).toList();
  }
  if (driver.isNotEmpty) {
    filteredVehicles = filteredVehicles.where((v) => namesMatch(v.chauffeurNom, driver)).toList();
  }

  final vImmatSet = filteredVehicles.map((v) => v.immatriculation).toSet();

  var filteredDeclarations = data.declarations;
  if (site.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) => vImmatSet.contains(d.vehicule)).toList();
  }
  if (vehicle.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) => d.vehicule == vehicle).toList();
  }
  if (driver.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) => namesMatch(d.chauffeur, driver)).toList();
  }
  if (criticite.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) => d.criticite == criticite).toList();
  }
  if (typePanne.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) => d.typePanne == typePanne).toList();
  }
  if (annee.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) => d.date.startsWith(annee)).toList();
  }
  if (mois.isNotEmpty) {
    filteredDeclarations = filteredDeclarations.where((d) =>
        d.date.length >= 7 ? d.date.substring(5, 7) == mois : false).toList();
  }
  if (period.isNotEmpty && period != '1a') {
    final days = period == '7j' ? 7 : period == '30j' ? 30 : period == '90j' ? 90 : 0;
    if (days > 0) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      filteredDeclarations = filteredDeclarations.where((d) {
        if (d.date.isEmpty) return false;
        final dd = DateTime.tryParse(d.date.length >= 10 ? d.date.substring(0, 10) : d.date);
        return dd != null && dd.isAfter(cutoff);
      }).toList();
    }
  }

  final vChauffeurs = filteredVehicles.map((v) => v.chauffeurNom).where((s) => s.isNotEmpty).toSet();
  final dChauffeurs = filteredDeclarations.map((d) => d.chauffeur).where((s) => s.isNotEmpty).toSet();
  final allDriverNames = {...vChauffeurs, ...dChauffeurs};
  var filteredDrivers = data.drivers.where((d) =>
      allDriverNames.any((n) => namesMatch(d.nom, n))).toList();
  if (ville.isNotEmpty) {
    filteredDrivers = filteredDrivers.where((d) => d.ville == ville).toList();
  }
  if (driver.isNotEmpty) {
    filteredDrivers = filteredDrivers.where((d) => namesMatch(d.nom, driver)).toList();
  }

  final total = filteredVehicles.length;
  final actifs = filteredVehicles.where((v) => v.statut == 'ACTIF').length;
  final arrete = filteredVehicles.where((v) => v.statut == 'BLOQUE' || v.statut == 'IMMOBILISE').length;
  final enMaint = filteredVehicles.where((v) => v.statut == 'MAINTENANCE').length;
  final totalKm = filteredVehicles.fold<double>(0, (s, v) => s + v.kilometrage);
  final decCount = filteredDeclarations.length;
  final decsOuvertes = filteredDeclarations.where((d) =>
      d.statut != 'CLOTURE' && d.statut != 'RESOLU' && d.statut != 'ANNULE').length;
  final decsCloturees = filteredDeclarations.where((d) =>
      d.statut == 'CLOTURE' || d.statut == 'RESOLU').length;
  final resolues = decsCloturees;
  final txReso = decCount > 0 ? (resolues / decCount * 100).round() : 0;
  final txUtil = total > 0 ? (actifs / total * 100).round() : 0;
  final txDispo = total > 0 ? ((total - arrete) / total * 100).round() : 0;
  final mtbf = decCount > 0 ? (totalKm / decCount).round() : 0;

  final slaPos = filteredDeclarations.where((d) => d.sla != 0).length;
  final slaOk = filteredDeclarations.where((d) => d.sla >= 0).length;

  final filteredKpis = <String, dynamic>{
    ...data.kpis,
    'totalVehicules': total,
    'enService': actifs,
    'aArret': arrete,
    'enMaintenance': enMaint,
    'bloques': arrete,
    'tauxUtilisation': txUtil,
    'anomaliesOuvertes': decsOuvertes,
    'totalKm': totalKm,
    'totalChauffeurs': filteredDrivers.length,
    'mttr': data.kpis['mttr'] ?? 0,
    'mtbf': mtbf,
    'slaCompliance': slaPos > 0 ? (slaOk / slaPos * 100).round() : 0,
    'totalDeclarations': decCount,
    'totalInterventions': data.kpis['totalInterventions'] ?? 0,
    'coutTotalMaintenance': data.kpis['coutTotalMaintenance'] ?? 0,
    'tauxDisponibilite': txDispo,
    'tempsMoyenReparation': data.kpis['tempsMoyenReparation'] ?? 0,
    'tempsMoyenValidation': data.kpis['tempsMoyenValidation'] ?? 0,
    'tauxResolution': txReso,
    'totalAnomalies': decCount,
    'declarationsCetteSemaine': 0,
    'declarationsCeMois': 0,
    'checkupsNonConformes': 0,
  };

  final marqueMap = <String, int>{};
  final agenceMap = <String, int>{};
  for (final v in filteredVehicles) {
    if (v.marque.isNotEmpty) marqueMap[v.marque] = (marqueMap[v.marque] ?? 0) + 1;
    if (v.agence.isNotEmpty) agenceMap[v.agence] = (agenceMap[v.agence] ?? 0) + 1;
  }
  final statutDecMap = <String, int>{};
  final critDecMap = <String, int>{};
  final typeDecMap = <String, int>{};
  final qualDecMap = <String, int>{};
  final catDecMap = <String, int>{};
  final elemDecMap = <String, int>{};
  final srcDecMap = <String, int>{};
  for (final d in filteredDeclarations) {
    if (d.statut.isNotEmpty) statutDecMap[d.statut] = (statutDecMap[d.statut] ?? 0) + 1;
    if (d.criticite.isNotEmpty) critDecMap[d.criticite] = (critDecMap[d.criticite] ?? 0) + 1;
    if (d.typePanne.isNotEmpty) typeDecMap[d.typePanne] = (typeDecMap[d.typePanne] ?? 0) + 1;
    if (d.qualification.isNotEmpty) qualDecMap[d.qualification] = (qualDecMap[d.qualification] ?? 0) + 1;
    if (d.categorie.isNotEmpty) catDecMap[d.categorie] = (catDecMap[d.categorie] ?? 0) + 1;
    if (d.element.isNotEmpty) elemDecMap[d.element] = (elemDecMap[d.element] ?? 0) + 1;
  }

  final evoGroups = <String, Map<String, dynamic>>{};
  for (final d in filteredDeclarations) {
    if (d.date.isEmpty) continue;
    final m = d.date.length >= 7 ? d.date.substring(0, 7) : d.date;
    final g = evoGroups.putIfAbsent(m, () => {
      'mois': m,
      'anomalies': 0,
      'resolues': 0,
      'critiques': 0,
      'checkups': 0,
      'checkupsOK': 0,
      'tickets': 0,
    });
    g['anomalies'] = (g['anomalies'] as int) + 1;
    if (d.statut == 'CLOTURE' || d.statut == 'RESOLU') {
      g['resolues'] = (g['resolues'] as int) + 1;
    }
    if (d.criticite == 'CRITIQUE' || d.criticite == 'BLOQUANT') {
      g['critiques'] = (g['critiques'] as int) + 1;
    }
  }
  final evoKeys2 = evoGroups.keys.toList()..sort();
  final filteredEvolution = evoKeys2.map((k) => evoGroups[k]!).toList();

  final filteredCharts = <String, dynamic>{
    ...data.charts,
    'anomaliesParSource': srcDecMap,
    'vehiculesParStatut': {
      'enService': actifs,
      'aArret': arrete,
      'enMaintenance': enMaint,
      'bloques': arrete,
    },
    'declarationsParStatut': statutDecMap,
    'declarationsParCriticite': critDecMap,
    'declarationsParTypePanne': typeDecMap,
    'declarationsParQualification': qualDecMap,
    'vehiculesParMarque': marqueMap,
    'anomaliesParElement': elemDecMap,
    'vehiculesParAgence': agenceMap,
    'declarationsParCategorie': catDecMap,
    'evolutionMensuelle': filteredEvolution,
    'pannesParElement': elemDecMap,
    'coutParMois': <String, double>{},
  };

  return data.copyWith(
    kpis: filteredKpis,
    charts: filteredCharts,
    vehicles: filteredVehicles,
    declarations: filteredDeclarations,
    drivers: filteredDrivers,
  );
}
