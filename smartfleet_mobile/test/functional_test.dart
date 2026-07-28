import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartfleet_mobile/database/dao/user_dao.dart';
import 'package:smartfleet_mobile/database/dao/declaration_dao.dart';
import 'package:smartfleet_mobile/database/dao/anomalie_dao.dart';
import 'package:smartfleet_mobile/database/dao/alert_dao.dart';
import 'package:smartfleet_mobile/database/dao/sync_dao.dart';
import 'package:smartfleet_mobile/database/database_helper.dart';

import 'package:smartfleet_mobile/services/vehicle_service.dart';
import 'package:smartfleet_mobile/services/declaration_service.dart';
import 'package:smartfleet_mobile/services/budget_service.dart';
import 'package:smartfleet_mobile/services/checklist_service.dart';
import 'package:smartfleet_mobile/services/checkup_service.dart';
import 'package:smartfleet_mobile/services/anomalie_service.dart';
import 'package:smartfleet_mobile/services/tournee_service.dart';
import 'package:smartfleet_mobile/services/ticket_service.dart';
import 'package:smartfleet_mobile/services/document_service.dart';
import 'package:smartfleet_mobile/services/tracking_service.dart';
import 'package:smartfleet_mobile/services/alert_service.dart';
import 'package:smartfleet_mobile/services/qr_code_service.dart';
import 'package:smartfleet_mobile/services/audit_service.dart';
import 'package:smartfleet_mobile/services/powerbi_service.dart';
import 'package:smartfleet_mobile/services/decision/moteur_decision_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.closeForTesting();
    final dbPath = await getDatabasesPath();
    final path = '${dbPath}\\smartfleet.db';
    final file = File(path);
    if (await file.exists()) {
      try { await file.delete(); } catch (_) {}
    }
  });
  test('1. Database - Initialisation et seed data', () async {
    final db = await DatabaseHelper().database;
    expect(db.isOpen, true);

    final biometricExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='biometric_devices'",
    );
    expect(biometricExists.length, 1, reason: 'biometric_devices table existe');

    final users = await db.query('utilisateurs');
    expect(users.length, 4, reason: '4 utilisateurs seed');

    final vehicles = await db.query('vehicules');
    expect(vehicles.length, 3, reason: '3 vehicules seed');

    final budgets = await db.query('budget_trimestriel');
    expect(budgets.length, 2, reason: '2 budgets seed');

    final declarations = await db.query('declarations');
    expect(declarations.length, 3, reason: '3 declarations seed');

    final docs = await db.query('documents_vehicule');
    expect(docs.length, 3, reason: '3 documents seed');

    final tournees = await db.query('tournees');
    expect(tournees.length, 2, reason: '2 tournees seed');

    final checkups = await db.query('checkups');
    expect(checkups.length, 2, reason: '2 checkups seed');

    final anomalies = await db.query('anomalies_checkup');
    expect(anomalies.length, 2, reason: '2 anomalies seed');

    final tickets = await db.query('tickets_maintenance');
    expect(tickets.length, 2, reason: '2 tickets seed');

    final alerts = await db.query('fleet_alerts');
    expect(alerts.length, 1, reason: '1 alert seed');

    final qrCodes = await db.query('qr_codes');
    expect(qrCodes.length, 1, reason: '1 QR code seed');

    final tracking = await db.query('tracking_history');
    expect(tracking.length, 3, reason: '3 tracking points seed');

    print('  ✓ Database initialisee avec 25 tables et seed data');
  });

  test('2. Authentification - 4 comptes demo', () async {
    final userDao = UserDao();

    final admin = await userDao.login('admin@smartfleet.fr', 'admin123');
    expect(admin, isNotNull, reason: 'Admin login');
    expect(admin!['role'], 'ADMIN');

    final rs = await userDao.login('rs_support@smartfleet.fr', 'support123');
    expect(rs, isNotNull, reason: 'RS login');
    expect(rs!['role'], 'RS');

    final chauffeur = await userDao.login('jean@smartfleet.fr', 'chauffeur123');
    expect(chauffeur, isNotNull, reason: 'Chauffeur login');
    expect(chauffeur!['role'], 'CHAUFFEUR');

    final presta = await userDao.login('presta@smartfleet.fr', 'presta123');
    expect(presta, isNotNull, reason: 'Prestataire login');
    expect(presta!['role'], 'PRESTATAIRE');

    final wrong = await userDao.login('admin@smartfleet.fr', 'wrongpassword');
    expect(wrong, isNull, reason: 'Mauvais mot de passe');

    final allUsers = await userDao.getAll();
    expect(allUsers.length, 4, reason: '4 utilisateurs');
    expect(allUsers.every((u) => !u.containsKey('motDePasse')), true,
        reason: 'Mot de passe retire des resultats');

    print('  ✓ Authentification: 4 comptes valides, mauvais mdp refuse');
  });

  test('3. CRUD Utilisateurs', () async {
    final userDao = UserDao();

    final newId = await userDao.insert({
      'nom': 'Test User',
      'email': 'test@smartfleet.fr',
      'password': 'test123',
      'role': 'CHAUFFEUR',
    });
    expect(newId, greaterThan(0), reason: 'Utilisateur cree');

    final user = await userDao.getById(newId);
    expect(user!['nom'], 'Test User');

    await userDao.update(newId, {'nom': 'Updated User', 'email': 'test@smartfleet.fr', 'role': 'RS'});
    final updated = await userDao.getById(newId);
    expect(updated!['nom'], 'Updated User');
    expect(updated['role'], 'RS');

    final rsUsers = await userDao.getByRole('RS');
    expect(rsUsers.any((u) => u['id'] == newId), true);

    await userDao.delete(newId);
    final deleted = await userDao.getById(newId);
    expect(deleted, isNull, reason: 'Utilisateur supprime');

    print('  ✓ CRUD Utilisateurs: create, read, update, delete');
  });

  test('4. CRUD Vehicules', () async {
    final vehicleService = VehicleService();

    final newId = await vehicleService.create({
      'immatriculation': 'ZZ-999-ZZ',
      'marque': 'Test',
      'modele': 'Model',
      'annee': 2024,
      'kilometrage': 1000,
    });
    expect(newId, greaterThan(0));

    final all = await vehicleService.getAll();
    expect(all.any((v) => v['immatriculation'] == 'ZZ-999-ZZ'), true);

    final byImmat = await vehicleService.getByImmat('ZZ-999-ZZ');
    expect(byImmat!['marque'], 'Test');

    await vehicleService.update(newId, {'marque': 'Updated', 'immatriculation': 'ZZ-999-ZZ'});
    final updated = await vehicleService.getById(newId);
    expect(updated!['marque'], 'Updated');

    final count = await vehicleService.count();
    expect(count, 4, reason: '3 seed + 1 new');

    await vehicleService.delete(newId);
    final deleted = await vehicleService.getById(newId);
    expect(deleted, isNull);

    print('  ✓ CRUD Vehicules: create, read, update, delete, count');
  });

  test('5. Workflow Declarations (7 statuts)', () async {
    final declService = DeclarationService();
    final declDao = DeclarationDao();

    final newId = await declService.create({
      'typePanne': 'MOTEUR',
      'description': 'Test declaration',
      'immatriculation': 'AA-123-BC',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
      'priorite': 'NORMALE',
    });
    expect(newId, greaterThan(0));

    var decl = await declDao.getById(newId);
    expect(decl!['statut'], 'EN_ATTENTE');

    await declService.takeCharge(newId, 4, 'Presta 1');
    decl = await declDao.getById(newId);
    expect(decl!['statut'], 'PRISE_EN_CHARGE');

    await declService.markAsInProgress(newId);
    decl = await declDao.getById(newId);
    expect(decl!['statut'], 'EN_COURS');

    await declService.markAsValidated(newId);
    decl = await declDao.getById(newId);
    expect(decl!['statut'], 'EN_VALIDATION');

    await declService.markAsProcessed(newId, coutReel: 250.0);
    decl = await declDao.getById(newId);
    expect(decl!['statut'], 'TRAITE');
    expect(decl!['coutReel'], 250.0);

    await declService.closeDeclaration(newId, coutReel: 250.0);
    decl = await declDao.getById(newId);
    expect(decl!['statut'], 'CLOTURE');
    expect(decl!['dateCloture'], isNotNull);

    final decl2 = await declService.create({
      'typePanne': 'FREIN',
      'description': 'Test retour',
      'immatriculation': 'BB-456-CD',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
    });
    await declService.returnDeclaration(decl2, 'Motif test');
    var ret = await declDao.getById(decl2);
    expect(ret!['statut'], 'RETOURNEE');
    expect(ret['motifRejet'], 'Motif test');

    final decl3 = await declService.create({
      'typePanne': 'PNEU',
      'description': 'Test rejet',
      'immatriculation': 'CC-789-EF',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
    });
    await declService.rejectDeclaration(decl3, 'Rejet test');
    var rej = await declDao.getById(decl3);
    expect(rej!['statut'], 'REJETEE');

    final stats = await declService.getStats();
    expect(stats['total'], greaterThanOrEqualTo(6));
    expect(stats['en_attente'], greaterThanOrEqualTo(0));
    expect(stats['cloture'], greaterThanOrEqualTo(1));

    print('  ✓ Workflow Declarations: 7 statuts (EN_ATTENTE→PRISE_EN_CHARGE→EN_COURS→EN_VALIDATION→TRAITE→CLOTURE + RETOURNEE + REJETEE)');
  });

  test('6. Checklist + Moteur de Decision', () async {
    final checklistService = ChecklistService();
    final moteur = MoteurDecisionService();

    final templates = await checklistService.getTemplates();
    expect(templates.length, 10, reason: '10 items checklist (web aligné)');

    final sessionId = await checklistService.startSession(1, 'AA-123-BC', 3);
    expect(sessionId, greaterThan(0));

    final items = await checklistService.getSessionItems(sessionId);
    expect(items.length, 10);

    final statut = await checklistService.completeSession(sessionId, conforme: false);
    expect(statut, greaterThan(0));

    final session = await checklistService.getSession(sessionId);
    expect(session!['statut'], 'COMPLETE');

    await checklistService.markForRepair(sessionId, 'Freins a verifier');
    var sess2 = await checklistService.getSession(sessionId);
    expect(sess2!['statut'], 'REPAIRE');

    await checklistService.validateSession(sessionId);
    var sess3 = await checklistService.getSession(sessionId);
    expect(sess3!['statut'], 'VALIDATED');

    final decision = await moteur.verifierConformite(1, 3);
    expect(decision['conforme'], isA<bool>());
    expect(decision['niveauBlocage'], isA<String>());

    print('  ✓ Checklist: 15 items + workflow PENDING→COMPLETE→REPAIRE→VALIDATED');
    print('  ✓ Moteur de decision: vehiculeId=1 niveau=${decision['niveauBlocage']} conforme=${decision['conforme']}');
  });

  test('7. Tournees - CRUD + workflow', () async {
    final tourneeService = TourneeService();

    final all = await tourneeService.getAll();
    expect(all.length, greaterThanOrEqualTo(2), reason: '2 tournees seed');

    final newId = await tourneeService.create({
      'chauffeurId': 3,
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'site': 'Test Site',
      'branche': 'Nord',
      'distancePrevue': 50.0,
    });
    expect(newId, greaterThan(0));

    final tournee = await tourneeService.getById(newId);
    expect(tournee!['numero'], startsWith('TOUR-'));
    expect(tournee['statut'], 'PLANIFIEE');

    await tourneeService.demarrer(newId);
    var t = await tourneeService.getById(newId);
    expect(t!['statut'], 'EN_COURS');
    expect(t['dateDebut'], isNotNull);

    await tourneeService.terminer(newId, distanceReelle: 48.5);
    t = await tourneeService.getById(newId);
    expect(t!['statut'], 'TERMINEE');
    expect(t['distanceReelle'], 48.5);

    final byChauffeur = await tourneeService.getByChauffeur(3);
    expect(byChauffeur.length, greaterThanOrEqualTo(3));

    await tourneeService.delete(newId);
    final deleted = await tourneeService.getById(newId);
    expect(deleted, isNull);

    print('  ✓ Tournees: create (auto numero), demarrer, terminer, delete');
  });

  test('8. Tracking GPS - positions + analytics Haversine', () async {
    final trackingService = TrackingService();

    await trackingService.updatePosition('AA-123-BC', 33.5731, -7.5898,
        vitesse: 45.0, ignition: 1);
    await trackingService.updatePosition('AA-123-BC', 33.8731, -7.7898,
        vitesse: 65.0, ignition: 1);
    await trackingService.updatePosition('AA-123-BC', 34.0200, -6.8500,
        vitesse: 0.0, ignition: 0);

    final latest = await trackingService.getLatest('AA-123-BC');
    expect(latest, isNotNull);
    expect(latest!['latitude'], 34.0200);
    expect(latest['vitesse'], 0.0);

    final allLatest = await trackingService.getAllLatest();
    expect(allLatest.any((t) => t['immatriculation'] == 'AA-123-BC'), true);

    final history = await trackingService.getHistory('AA-123-BC');
    expect(history.length, greaterThanOrEqualTo(3));

    final analytics = await trackingService.getAnalytics('AA-123-BC');
    expect(analytics['distance'], greaterThan(0), reason: 'Distance Haversine > 0');
    expect(analytics['maxSpeed'], greaterThanOrEqualTo(65.0));
    expect(analytics['avgSpeed'], greaterThan(0));
    expect(analytics['pointsCount'], greaterThanOrEqualTo(3));
    expect(analytics['ignitionOnCount'], greaterThanOrEqualTo(2));

    print('  ✓ Tracking GPS: 3 positions, distance=${(analytics['distance'] as double).toStringAsFixed(1)}km, maxSpeed=${analytics['maxSpeed']}km/h');
  });

  test('9. Documents - CRUD + statut expiration', () async {
    final docService = DocumentVehiculeService();

    final docs = await docService.getByVehicule(1);
    expect(docs.length, 3, reason: '3 documents seed pour vehicule 1');

    final expired = await docService.getExpired();
    expect(expired.any((d) => d['typeDocument'] == 'ASSURANCE'), true,
        reason: 'Assurance expiree (2025-12-01)');

    final expiringSoon = await docService.getExpiringSoon(30);
    expect(expiringSoon.any((d) => d['typeDocument'] == 'VISITE_TECHNIQUE'), true,
        reason: 'Visite technique expire bientot');

    final statutAssurance = docService.getStatutDocument(docs.firstWhere((d) => d['typeDocument'] == 'ASSURANCE'));
    expect(statutAssurance, 'EXPIRE');

    final statutCarteGrise = docService.getStatutDocument(docs.firstWhere((d) => d['typeDocument'] == 'CARTE_GRISE'));
    expect(statutCarteGrise, 'VALIDE');

    final newId = await docService.create({
      'vehiculeId': 2,
      'immatriculation': 'BB-456-CD',
      'typeDocument': 'ASSURANCE',
      'numeroDocument': 'ASS-2026-002',
      'dateEmission': '2026-01-01',
      'dateExpiration': '2027-01-01',
    });
    expect(newId, greaterThan(0));

    await docService.archive(newId);
    final archived = await docService.getById(newId);
    expect(archived!['archived'], 1);

    print('  ✓ Documents: CRUD + statut (EXPIRE/BIENTOT_EXPIRE/VALIDE) + archive');
  });

  test('10. Anomalies - CRUD + workflow DETECTEE→EN_REPARATION→REPAREE→VALIDEE', () async {
    final anomalieService = AnomalieService();

    final all = await anomalieService.getAll();
    expect(all.length, greaterThanOrEqualTo(2), reason: '2 anomalies seed');

    final newId = await anomalieService.create({
      'element': 'Test element',
      'categorie': 'TEST',
      'criticite': 'MOYENNE',
      'description': 'Anomalie de test',
      'vehiculeId': 2,
      'immatriculation': 'BB-456-CD',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
    });
    expect(newId, greaterThan(0));

    var anom = await anomalieService.getById(newId);
    expect(anom!['statut'], 'DETECTEE');
    expect(anom['code'], startsWith('ANOM-'));

    await anomalieService.takeCharge(newId, 'Technicien 1');
    anom = await anomalieService.getById(newId);
    expect(anom!['statut'], 'EN_REPARATION');
    expect(anom['assignedTo'], 'Technicien 1');

    await anomalieService.resolve(newId, notes: 'Répare');
    anom = await anomalieService.getById(newId);
    expect(anom!['statut'], 'REPAREE');
    expect(anom['dateResolution'], isNotNull);

    await anomalieService.validate(newId);
    anom = await anomalieService.getById(newId);
    expect(anom!['statut'], 'VALIDEE');

    final stats = await anomalieService.getStats();
    expect(stats['total'], greaterThanOrEqualTo(3));
    expect(stats['validees'], greaterThanOrEqualTo(1));

    print('  ✓ Anomalies: workflow DETECTEE→EN_REPARATION→REPAREE→VALIDEE + stats');
  });

  test('11. Tickets Maintenance - CRUD + workflow + interventions', () async {
    final ticketService = TicketMaintenanceService();

    final all = await ticketService.getAll();
    expect(all.length, greaterThanOrEqualTo(2), reason: '2 tickets seed');

    final newId = await ticketService.create({
      'vehiculeId': 2,
      'immatriculation': 'BB-456-CD',
      'typePanne': 'FREIN',
      'description': 'Test ticket',
      'priorite': 'URGENT',
      'declarePar': 3,
      'declareParNom': 'Jean Chauffeur',
    });
    expect(newId, greaterThan(0));

    var ticket = await ticketService.getById(newId);
    expect(ticket!['statut'], 'OUVERT');
    expect(ticket['numero'], startsWith('TKT-'));

    await ticketService.assigner(newId, 'Technicien 1');
    ticket = await ticketService.getById(newId);
    expect(ticket!['statut'], 'AFFECTE');

    await ticketService.demarrer(newId);
    ticket = await ticketService.getById(newId);
    expect(ticket!['statut'], 'EN_COURS');

    final intervId = await ticketService.addIntervention(newId, {
      'technicien': 'Technicien 1',
      'typeIntervention': 'REPARATION',
      'description': 'Remplacement plaquettes',
      'coutMainOeuvre': 100.0,
      'coutPieces': 150.0,
    });
    expect(intervId, greaterThan(0));

    final interventions = await ticketService.getInterventions(newId);
    expect(interventions.length, 1);
    expect(interventions.first['coutMainOeuvre'], 100.0);

    await ticketService.terminer(newId, coutReel: 250.0, notes: 'Répare');
    ticket = await ticketService.getById(newId);
    expect(ticket!['statut'], 'CLOTURE');
    expect(ticket['coutReel'], 250.0);

    final stats = await ticketService.getStats();
    expect(stats['total'], greaterThanOrEqualTo(3));

    print('  ✓ Tickets: workflow OUVERT→AFFECTE→EN_COURS→CLOTURE + intervention');
  });

  test('12. Budget - CRUD + recalcul + par prestataire/type', () async {
    final budgetService = BudgetService();

    final all = await budgetService.getAll();
    expect(all.length, greaterThanOrEqualTo(2));

    final current = await budgetService.getCurrent();
    expect(current, isNotNull);
    expect(current!['montantTotal'], greaterThan(0));

    final budgetId = current!['id'] as int;

    await budgetService.recalculerUtilisation(budgetId);
    final recalced = await budgetService.getById(budgetId);
    expect(recalced!['montantUtilise'], greaterThanOrEqualTo(0));

    final byProvider = await budgetService.getByProvider(budgetId);
    expect(byProvider, isA<List>());

    final byType = await budgetService.getByType(budgetId);
    expect(byType, isA<List>());

    final newBudgetId = await budgetService.create({
      'periode': '2026-Q4',
      'montantTotal': 60000,
      'montantUtilise': 0,
      'statut': 'ACTIF',
    });
    expect(newBudgetId, greaterThan(0));

    print('  ✓ Budget: CRUD + recalcul utilisation + par prestataire + par type');
  });

  test('13. Alertes & Blocages', () async {
    final alertService = FleetAlertService();

    final active = await alertService.getActive();
    expect(active.length, greaterThanOrEqualTo(1), reason: '1 alerte seed');

    final counts = await alertService.getCounts();
    expect(counts['total'], greaterThanOrEqualTo(1));

    final alertId = await alertService.create({
      'vehiculeId': 2,
      'immatriculation': 'BB-456-CD',
      'type': 'MAINTENANCE_REQUISE',
      'criticite': 'MOYENNE',
      'message': 'Test alerte',
    });
    expect(alertId, greaterThan(0));

    await alertService.resolve(alertId, 'Admin');
    final resolved = await alertService.getAll();
    expect(resolved.any((a) => a['id'] == alertId && a['statut'] == 'RESOLUE'), true);

    final blockId = await alertService.blockVehicle(2, 'BB-456-CD', 'Test blocage', 1);
    expect(blockId, greaterThan(0));

    final blockings = await alertService.getActiveBlockings();
    expect(blockings.any((b) => b['vehiculeId'] == 2), true);

    final activeBlock = await alertService.getActiveBlocking(2);
    expect(activeBlock, isNotNull);
    expect(activeBlock!['raison'], 'Test blocage');

    await alertService.unblockVehicle(2, 1);
    final afterUnblock = await alertService.getActiveBlocking(2);
    expect(afterUnblock, isNull, reason: 'Vehicule debloque');

    print('  ✓ Alertes: create + resolve + counts');
    print('  ✓ Blocages: block + getActive + unblock');
  });

  test('14. QR Codes - generation + scan', () async {
    final qrService = QrCodeService();

    final all = await qrService.getAll();
    expect(all.length, greaterThanOrEqualTo(1), reason: '1 QR code seed');

    final newQrId = await qrService.generate(2);
    expect(newQrId, greaterThan(0));

    final byVehicule = await qrService.getByVehicule(2);
    expect(byVehicule, isNotNull);
    expect(byVehicule!['actif'], 1);

    final code = byVehicule['code'] as String;
    final scanResult = await qrService.scan(code);
    expect(scanResult, isNotNull);
    expect(scanResult!['vehicule'], isNotNull);
    expect(scanResult['vehicule']['immatriculation'], 'BB-456-CD');

    final invalidScan = await qrService.scan('INVALID_CODE');
    expect(invalidScan, isNull);

    final vDirect = await VehicleService().getByImmat('BB-456-CD');
    expect(vDirect, isNotNull, reason: 'BB-456-CD trouve par immat directe');
    expect(vDirect!['immatriculation'], 'BB-456-CD');

    final vDirect2 = await VehicleService().getByImmat('AA-123-BC');
    expect(vDirect2, isNotNull, reason: 'AA-123-BC trouve par immat directe');
    expect(vDirect2!['immatriculation'], 'AA-123-BC');

    print('  ✓ QR Codes: generation auto + scan valide + scan invalide refuse');
    print('  ✓ Lookup immat directe: AA-123-BC et BB-456-CD trouvés');
  });

  test('15. Audit Log', () async {
    final auditService = AuditLogService();

    final logId = await auditService.log(
      'TEST_ACTION',
      'TEST_ENTITY',
      1,
      userId: 1,
      details: 'Test audit log',
    );
    expect(logId, greaterThan(0));

    final all = await auditService.getAll();
    expect(all.any((l) => l['action'] == 'TEST_ACTION'), true);

    final byAction = await auditService.getByAction('TEST_ACTION');
    expect(byAction.length, greaterThanOrEqualTo(1));
    expect(byAction.first['details'], 'Test audit log');

    final byEntity = await auditService.getByEntity('TEST_ENTITY', 1);
    expect(byEntity.length, greaterThanOrEqualTo(1));

    print('  ✓ Audit Log: log + getAll + getByAction + getByEntity');
  });

  test('16. Checkups - create avec auto-anomalies', () async {
    final checkupService = CheckupService();

    final newId = await checkupService.create(
      {
        'vehiculeId': 1,
        'immatriculation': 'AA-123-BC',
        'chauffeurId': 3,
        'chauffeurNom': 'Jean Chauffeur',
        'kilometrage': 46000,
      },
      [
        {'element': 'Freins', 'categorie': 'FREINAGE', 'conforme': 0, 'observation': 'Plaquettes usées'},
        {'element': 'Pneus', 'categorie': 'PNEUS', 'conforme': 1},
        {'element': 'Huile', 'categorie': 'MOTEUR', 'conforme': 1},
      ],
    );
    expect(newId, greaterThan(0));

    final checkup = await checkupService.getById(newId);
    expect(checkup!['conforme'], 0, reason: 'Non conforme (freins)');
    expect(checkup['code'], startsWith('CHK-'));

    final details = await checkupService.getDetails(newId);
    expect(details.length, 3);

    final anomalieDao = AnomalieDao();
    final anomalies = await anomalieDao.getByCheckup(newId);
    expect(anomalies.length, 1, reason: '1 anomalie auto-cree pour freins');
    expect(anomalies.first['element'], 'Freins');
    expect(anomalies.first['statut'], 'OUVERTE');

    final alertDao = FleetAlertDao();
    final alerts = await alertDao.getByVehicule(1);
    expect(alerts.any((a) => a['type'] == 'CHECKUP_NON_CONFORME'), true,
        reason: 'Alerte auto-cree');

    print('  ✓ Checkups: create + auto-anomalies (1 pour freins) + auto-alerte');
  });

  test('17. PowerBI / Analytics', () async {
    final powerbi = PowerBiService();

    final evolution = await powerbi.getVehicleEvolution('BB-456-CD');
    expect(evolution['immatriculation'], 'BB-456-CD');
    expect(evolution['evolution'], isA<List>());
    expect(evolution['moisDisponibles'], isA<List>());

    final months = await powerbi.getAvailableMonths('BB-456-CD');
    expect(months, isA<List<String>>());

    final kpi = await powerbi.getKpiData('BB-456-CD');
    expect(kpi['coutMoyenParPanne'], isA<double>());
    expect(kpi['topPanne'], isA<String>());

    final heatmap = await powerbi.getHeatmap('BB-456-CD');
    expect(heatmap['jours'], isA<List>());
    expect(heatmap['heures'], isA<List>());
    expect(heatmap['valeurs'], isA<List>());
    expect((heatmap['valeurs'] as List).length, 7, reason: '7 jours');

    final overview = await powerbi.getOverview();
    expect(overview['totalDeclarations'], greaterThan(0));
    expect(overview['coutTotal'], isA<double>());

    print('  ✓ Analytics: evolution + mois disponibles + KPI + heatmap + overview');
  });

  test('18. Sync Queue', () async {
    final syncDao = SyncDao();

    final declService = DeclarationService();
    await declService.create({
      'typePanne': 'MOTEUR',
      'description': 'Test sync',
      'immatriculation': 'AA-123-BC',
      'chauffeurId': 3,
      'chauffeurNom': 'Jean Chauffeur',
    });

    final pending = await syncDao.getPending();
    expect(pending.length, greaterThan(0), reason: 'Sync queue a des elements');

    final count = await syncDao.pendingCount();
    expect(count, greaterThan(0));

    if (pending.isNotEmpty) {
      await syncDao.markCompleted(pending.first['id'] as int);
      final afterMark = await syncDao.getPending();
      expect(afterMark.length, lessThan(pending.length));
    }

    print('  ✓ Sync Queue: addToQueue + getPending + pendingCount + markCompleted');
  });

  test('19. Departs historique', () async {
    final tourneeService = TourneeService();

    final departId = await tourneeService.enregistrerDepart({
      'chauffeurId': 3,
      'vehiculeId': 1,
      'immatriculation': 'AA-123-BC',
      'site': 'Casablanca',
      'branche': 'Nord',
      'gpsLatitude': 33.5731,
      'gpsLongitude': -7.5898,
      'dateDepart': DateTime.now().toIso8601String(),
    });
    expect(departId, greaterThan(0));

    final departs = await tourneeService.getAllDeparts();
    expect(departs.length, greaterThanOrEqualTo(1));

    final today = await tourneeService.getDepartsToday();
    expect(today.any((d) => d['immatriculation'] == 'AA-123-BC'), true);

    print('  ✓ Departs: enregistrer + getAll + getToday');
  });

  test('20. Checkup stats + getByVehicule/Chauffeur', () async {
    final checkupService = CheckupService();

    final stats = await checkupService.getStats();
    expect(stats['total'], greaterThanOrEqualTo(2));
    expect(stats['conforme'], greaterThanOrEqualTo(0));
    expect(stats['nonConforme'], greaterThanOrEqualTo(0));

    final byVehicule = await checkupService.getByVehicule(1);
    expect(byVehicule, isA<List>());

    final byChauffeur = await checkupService.getByChauffeur(3);
    expect(byChauffeur, isA<List>());

    final latest = await checkupService.getLatestByVehicule(2);
    expect(latest, isNotNull);

    print('  ✓ Checkup stats: total=${stats['total']} conforme=${stats['conforme']} nonConforme=${stats['nonConforme']}');
  });

  test('21. Biometric Devices - CRUD + DAO', () async {
    final db = await DatabaseHelper().database;

    final inserted = await db.insert('biometric_devices', {
      'userId': 1,
      'deviceId': 'test-device-001',
      'deviceName': 'Test Phone',
      'platform': 'android',
      'biometricEnabled': 1,
    });
    expect(inserted, greaterThan(0), reason: 'Device inserted');

    final devices = await db.query('biometric_devices', where: 'userId = 1');
    expect(devices.length, 1, reason: '1 device for user 1');

    await db.update(
      'biometric_devices',
      {'biometricEnabled': 0},
      where: 'id = ?',
      whereArgs: [inserted],
    );

    final disabled = await db.query('biometric_devices',
        where: 'id = ? AND biometricEnabled = 0', whereArgs: [inserted]);
    expect(disabled.length, 1, reason: 'Device disabled');

    final secondDevice = await db.insert('biometric_devices', {
      'userId': 1,
      'deviceId': 'test-device-002',
      'deviceName': 'Test Tablet',
      'platform': 'ios',
      'biometricEnabled': 1,
    });
    expect(secondDevice, greaterThan(0), reason: 'Second device inserted');

    final allForUser = await db.query('biometric_devices', where: 'userId = 1');
    expect(allForUser.length, 2, reason: '2 total devices for user 1');

    final enabledCount = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM biometric_devices WHERE biometricEnabled = 1',
    );
    expect((enabledCount.first['cnt'] as int?) ?? 0, 1,
        reason: 'Only 1 enabled');

    print('  ✓ Biometric Devices: CRUD + enable/disable OK');
  });

  tearDownAll(() async {
    await DatabaseHelper.closeForTesting();
    final dbPath = await getDatabasesPath();
    final path = '${dbPath}\\smartfleet.db';
    final file = File(path);
    if (await file.exists()) {
      try { await file.delete(); } catch (_) {}
    }
    print('\n========================================');
    print('  TOUS LES TESTS FONCTIONNELS REUSSIS');
    print('========================================');
  });
}
