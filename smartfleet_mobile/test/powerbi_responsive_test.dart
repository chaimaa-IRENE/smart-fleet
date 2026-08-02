import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartfleet_mobile/features/analytics/powerbi_data.dart';
import 'package:smartfleet_mobile/features/analytics/powerbi_executive_view.dart';
import 'package:smartfleet_mobile/features/analytics/powerbi_anomaly_view.dart';
import 'package:smartfleet_mobile/features/analytics/powerbi_vehicle_detail_view.dart';
import 'package:smartfleet_mobile/features/analytics/powerbi_drivers_view.dart';

DashboardData _sample() {
  final vehicles = <VehicleRow>[
    for (int i = 0; i < 24; i++)
      VehicleRow(
        id: i,
        immatriculation: '1-ABC-$i',
        numeroOrdre: 'VIN$i',
        marque: ['Renault', 'Volvo', 'Mercedes', 'Iveco'][i % 4],
        modele: 'Model ${i % 3}',
        type: 'Camion',
        annee: 2019.0 + (i % 5),
        kilometrage: 50000.0 + i * 1000,
        statut: ['ACTIF', 'MAINTENANCE', 'BLOQUE', 'IMMOBILISE'][i % 4],
        agence: 'Agence Casablanca',
        chauffeurNom: i % 2 == 0 ? 'Mohammed Ali' : 'Karim Bennani',
        carburant: i % 2 == 0 ? 'Diesel' : 'Essence',
        conforme: true,
        anomalies: 2 + i,
        checkups: 3,
        tickets: 1,
        documents: 3,
        documentsValides: 2,
        scoreIVMS: (40 + (i * 3) % 60).toDouble(),
      ),
  ];

  final declarations = <DeclarationRow>[
    for (int i = 0; i < 34; i++)
      DeclarationRow(
        id: i,
        numeroDemande: 'DM-2025-00$i',
        vehicule: i % 4 == 0 ? '1-ABC-0' : '1-ABC-${i % 24}',
        chauffeur: i % 2 == 0 ? 'Mohammed Ali' : 'Karim Bennani',
        typePanne: ['Moteur', 'Freinage', 'Boîte', 'Suspension'][i % 4],
        criticite: ['MINEURE', 'MAJEURE', 'CRITIQUE'][i % 3],
        statut: ['OUVERT', 'EN_COURS', 'CLOTURE', 'ANNULE'][i % 4],
        qualification: i % 2 == 0 ? 'PREVENTIVE' : 'CURATIVE',
        element: ['Frein', 'Moteur', 'Pneu', 'Alternateur'][i % 4],
        categorie: 'Mécanique',
        date: i % 2 == 0 ? '2025-06-15' : '2025-05-20',
        cout: 500.0 + i * 100,
        sla: 48,
        description: 'Description $i',
      ),
  ];

  final drivers = <DriverRow>[
    for (int i = 0; i < 8; i++)
      DriverRow(
        nom: i % 2 == 0 ? 'Mohammed Ali' : 'Karim Bennani',
        matricule: 'CHF00$i',
        email: 'd$i@fleet.ma',
        phone: '06000000$i',
        ville: 'Casablanca',
        branchCode: 'CAS',
        anomalies: 4 + i,
        checkups: 10,
        checkupsOK: 8 + i % 3,
        tauxConformite: 60 + i * 4,
        tauxResolution: 55 + i * 5,
        departs: 12,
        presences: 22,
        score: 45 + i * 6,
        vehicules: const ['1-ABC-0'],
        interventions: 6,
        coutTotal: 8000.0,
      ),
  ];

  final documents = <DocumentRow>[
    for (int i = 0; i < 6; i++)
      DocumentRow(
        vehicule: '1-ABC-$i',
        type: ['Assurance', 'Carte grise', 'Vignette'][i % 3],
        dateExpiration: '2026-01-0$i',
        joursRestants: [-5, 10, 60, 120, 200, 300][i],
      ),
  ];

  final alerts = <AlertRow>[
    AlertRow(type: 'Maintenance', message: 'Véhicule 1-ABC-1 nécessite une intervention urgente', severite: 'HAUTE', immatriculation: '1-ABC-1'),
    AlertRow(type: 'Document', message: 'Assurance expirée pour 1-ABC-2', severite: 'MOYENNE', immatriculation: '1-ABC-2'),
    AlertRow(type: 'Anomalie', message: 'Anomalie critique détectée sur 1-ABC-3', severite: 'HAUTE', immatriculation: '1-ABC-3'),
    AlertRow(type: 'Check-up', message: 'Check-up en retard', severite: 'BASSE', immatriculation: '1-ABC-4'),
  ];

  return DashboardData(
    kpis: {
      'totalVehicules': 24,
      'enService': 14,
      'aArret': 5,
      'enMaintenance': 3,
      'bloques': 2,
      'tauxUtilisation': 72,
      'anomaliesOuvertes': 8,
      'totalCheckups30j': 12,
      'totalKm': 245000,
      'consoMoyenne': 9.5,
      'vitesseMoyenne': 62.4,
      'slaCompliance': 81,
      'totalDeclarations': 34,
      'totalPrestataires': 3,
      'totalInterventions': 11,
      'interventionsEnCours': 4,
      'interventionsTerminees': 6,
      'interventionsEnRetard': 1,
      'budgetConsomme': 85000,
      'budgetRestant': 45000,
      'coutTotalMaintenance': 78000,
      'documentsExpires': 2,
      'documentsBientotExpire': 3,
      'tauxDisponibilite': 78,
      'declarationsAujourdhui': 3,
      'declarationsCeMois': 22,
      'mttr': 18,
      'ticketsOuverts': 5,
      'mtbf': 14,
      'txCheckupConformite': 76,
    },
    charts: {
      'anomaliesParSource': {'Capteur': 5, 'Conducteur': 3, 'Inspection': 4},
      'vehiculesParMarque': {'Renault': 6, 'Volvo': 4, 'Mercedes': 3, 'Iveco': 2},
      'declarationsParTypePanne': {'Moteur': 4, 'Freinage': 3, 'Boîte': 2, 'Suspension': 2},
      'declarationsParQualification': {'PREVENTIVE': 6, 'CURATIVE': 4},
      'interventionsParPrestataire': {'Presta A': 5, 'Presta B': 3},
      'documentsParType': {'Assurance': 4, 'Carte grise': 3, 'Vignette': 2},
      'declarationsParCategorie': {'Mécanique': 4, 'Électrique': 3},
      'declarationsParCriticite': {'MINEURE': 4, 'MAJEURE': 3, 'CRITIQUE': 2},
      'declarationsParStatut': {'OUVERT': 4, 'EN_COURS': 3, 'CLOTURE': 5, 'ANNULE': 1},
      'anomaliesParElement': {'Frein': 3, 'Moteur': 4, 'Pneu': 2},
      'evolutionMensuelle': [
        {'mois': '2025-01', 'anomalies': 3, 'resolues': 2, 'checkups': 5, 'tickets': 1, 'critiques': 1},
        {'mois': '2025-02', 'anomalies': 4, 'resolues': 3, 'checkups': 4, 'tickets': 2, 'critiques': 1},
        {'mois': '2025-03', 'anomalies': 5, 'resolues': 4, 'checkups': 6, 'tickets': 2, 'critiques': 2},
        {'mois': '2025-04', 'anomalies': 3, 'resolues': 3, 'checkups': 5, 'tickets': 1, 'critiques': 0},
        {'mois': '2025-05', 'anomalies': 6, 'resolues': 4, 'checkups': 7, 'tickets': 3, 'critiques': 2},
        {'mois': '2025-06', 'anomalies': 4, 'resolues': 5, 'checkups': 6, 'tickets': 2, 'critiques': 1},
      ],
    },
    vehicles: vehicles,
    declarations: declarations,
    drivers: drivers,
    documents: documents,
    alerts: alerts,
    budgetAnalysis: const [
      {'mois': '2025-01', 'budget': 12000.0, 'cout': 9800.0},
      {'mois': '2025-02', 'budget': 12000.0, 'cout': 11500.0},
      {'mois': '2025-03', 'budget': 12000.0, 'cout': 10200.0},
      {'mois': '2025-04', 'budget': 12000.0, 'cout': 12500.0},
    ],
    activeBudget: const {'montant': 12000, 'consomme': 9800, 'restant': 2200},
    documentStats: const {'valides': 8, 'expires': 2, 'bientotExpires': 3},
    aiInsights: const [
      {'message': 'La consommation moyenne est stable ce mois-ci.', 'tendance': 'stable', 'recommandation': 'Maintenir les habitudes actuelles.'},
      {'message': 'Hausse des anomalies critiques sur les moteurs.', 'tendance': 'hausse', 'recommandation': 'Planifier une campagne de maintenance préventive.'},
    ],
    filterOptions: {
      'sites': ['Casablanca', 'Rabat'],
      'vehicles': [{'immatriculation': '1-ABC-0'}],
      'drivers': ['Mohammed Ali'],
      'status': ['ACTIF', 'MAINTENANCE'],
      'criticites': ['MINEURE', 'MAJEURE', 'CRITIQUE'],
      'typesPanne': ['Moteur', 'Freinage'],
      'regions': ['Grand Casablanca'],
      'prestataires': ['Presta A', 'Presta B'],
      'villes': ['Casablanca'],
      'annees': ['2025'],
      'mois': ['2025-01'],
    },
  );
}

Future<void> _pumpView(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            child: view,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final data = _sample();

  testWidgets('ExecutiveDashboardView no overflow at 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpView(tester, ExecutiveDashboardView(data: data));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Executive overflow at 320px');
  });

  testWidgets('AnomalyAnalysisView no overflow at 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpView(tester, AnomalyAnalysisView(data: data));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Anomaly overflow at 320px');
  });

  testWidgets('VehicleDetailView no overflow at 320x568 (with selection)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpView(tester, VehicleDetailView(data: data));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'VehicleDetail initial overflow');

    await tester.tap(find.text('1-ABC-3').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull,
        reason: 'VehicleDetail overflow after selection');
  });

  testWidgets('DriverPerformanceView no overflow at 320x568 (with selection)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpView(tester, DriverPerformanceView(data: data));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'DriverPerformance initial overflow');

    await tester.tap(find.text('Mohammed Ali').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull,
        reason: 'DriverPerformance overflow after selection');
  });

  testWidgets('All views no overflow at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpView(tester, ExecutiveDashboardView(data: data));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Executive overflow at 360px');

    await _pumpView(tester, AnomalyAnalysisView(data: data));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Anomaly overflow at 360px');
  });
}
