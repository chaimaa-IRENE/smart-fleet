import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartfleet_mobile/database/database_helper.dart';
import 'package:smartfleet_mobile/services/scan_code_service.dart';
import 'package:smartfleet_mobile/services/qr_code_service.dart';
import 'package:smartfleet_mobile/services/checklist_service.dart';

/// Tests du flux « scan avant check-up » : le code scanné (QR code ou
/// code-barres 1D) est résolu vers un véhicule, puis une session checklist
/// démarre pour ce véhicule.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.testDatabasesPathOverride = join(
      Directory.current.path,
      '.dart_tool',
      'sqflite_common_ffi',
      'databases',
      'scan_before_checkup',
    );
  });

  setUp(() async {
    await DatabaseHelper.closeForTesting();
    final path = join(DatabaseHelper.testDatabasesPathOverride!, 'smartfleet.db');
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  });

  group('ScanCodeService.immatVariants (normalisation)', () {
    test('7 caractères sans tirets -> format AA-AAA-AA', () {
      final v = ScanCodeService.immatVariants('BB456CD');
      expect(v, contains('BB-456-CD'));
    });

    test('6 caractères sans tirets -> format AA-AA-AA', () {
      final v = ScanCodeService.immatVariants('AB12CD');
      expect(v, contains('AB-12-CD'));
    });

    test('avec tirets -> variante sans tirets incluse', () {
      final v = ScanCodeService.immatVariants('BB-456-CD');
      expect(v, contains('BB456CD'));
      expect(v, contains('BB-456-CD'));
    });

    test('8 caractères -> variantes de formats', () {
      final v = ScanCodeService.immatVariants('AB123CD');
      expect(v, contains('AB-123-CD'));
    });

    test('>= 9 caractères -> variante XX-...', () {
      final v = ScanCodeService.immatVariants('AA12345678');
      expect(v, contains('AA-12345678'));
    });
  });

  group('Scan avant check-up : résolution du code vers le véhicule', () {
    test('un QR code seed résout le bon véhicule', () async {
      final r = await ScanCodeService().resolve('QR-1234567890');
      expect(r, isNotNull);
      expect(r!['immatriculation'], 'AA-123-BC');
      expect(r['id'], 1);
    });

    test('un QR code nouvellement généré résout le véhicule', () async {
      await QrCodeService().generate(3);
      final all = await QrCodeService().getAll();
      final qr = all.firstWhere((q) => q['vehiculeId'] == 3);
      final r = await ScanCodeService().resolve(qr['code'] as String);
      expect(r, isNotNull);
      expect(r!['immatriculation'], 'CC-789-EF');
      expect(r['id'], 3);
    });

    test('une immatriculation scannée (code-barres) résout le véhicule', () async {
      final r = await ScanCodeService().resolve('BB-456-CD');
      expect(r, isNotNull);
      expect(r!['immatriculation'], 'BB-456-CD');
      expect(r['id'], 2);
    });

    test('immatriculation sans tirets (EAN-13 / Code-128) résout le véhicule',
        () async {
      final r = await ScanCodeService().resolve('BB456CD');
      expect(r, isNotNull);
      expect(r!['immatriculation'], 'BB-456-CD');
    });

    test('immatriculation en minuscules résout le véhicule', () async {
      final r = await ScanCodeService().resolve('cc-789-ef');
      expect(r, isNotNull);
      expect(r!['immatriculation'], 'CC-789-EF');
    });

    test('un code inconnu renvoie null (aucun démarrage possible)', () async {
      final r = await ScanCodeService().resolve('ZZ-999-XX');
      expect(r, isNull);
    });

    test('un code vide renvoie null', () async {
      expect(await ScanCodeService().resolve('   '), isNull);
    });
  });

  group('Scan avant check-up : démarrage de la session', () {
    test('session créée pour le véhicule scanné avec items des templates',
        () async {
      final r = await ScanCodeService().resolve('BB-456-CD');
      expect(r, isNotNull);

      final svc = ChecklistService();
      final sessionId =
          await svc.startSession(r!['id'] as int, r['immatriculation'] as String, 3,);

      final session = await svc.getSession(sessionId);
      expect(session, isNotNull);
      expect(session!['vehiculeId'], 2);
      expect(session['immatriculation'], 'BB-456-CD');
      expect(session['chauffeurId'], 3);
      expect(session['statut'], 'PENDING');

      final items = await svc.getSessionItems(sessionId);
      expect(items.length, greaterThan(0),
          reason: 'les items doivent être alimentés depuis les templates',);
    });

    test('un scan invalide ne démarre aucune session', () async {
      final r = await ScanCodeService().resolve('ZZ-999-XX');
      expect(r, isNull);

      final sessions = await ChecklistService().getMySessions(3);
      expect(sessions, isEmpty);
    });
  });
}
