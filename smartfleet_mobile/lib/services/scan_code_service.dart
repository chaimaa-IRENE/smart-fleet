import 'qr_code_service.dart';
import 'vehicle_service.dart';

/// Résout un code scanné (QR code ou code-barres 1D) vers un véhicule, pour
/// le scan avant check-up.
///
/// Le code scanné peut être :
///  - un QR code enregistré en base (table `qr_codes`),
///  - une immatriculation (ex : `BB-456-CD`), éventuellement sans séparateurs
///    (ex : `BB456CD`) comme délivrée par un code-barres EAN-13 / Code-128.
class ScanCodeService {
  final QrCodeService _qrSvc;
  final VehicleService _vehicleSvc;

  ScanCodeService({QrCodeService? qrSvc, VehicleService? vehicleSvc})
      : _qrSvc = qrSvc ?? QrCodeService(),
        _vehicleSvc = vehicleSvc ?? VehicleService();

  /// Génère les variantes normalisées d'une immatriculation scannée
  /// (suppression des séparateurs, formats avec tirets).
  ///
  /// Entrée attendue : chaîne déjà en majuscules (voir [resolve]).
  static List<String> immatVariants(String raw) {
    final variants = <String>{};
    final clean = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean != raw) variants.add(clean);
    if (clean.length == 7) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2, 5)}-${clean.substring(5)}');
    }
    if (clean.length == 6) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2, 4)}-${clean.substring(4)}');
    }
    if (clean.length == 8) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2, 6)}-${clean.substring(6)}');
      variants.add('${clean.substring(0, 3)}-${clean.substring(3, 5)}-${clean.substring(5)}');
    }
    if (clean.length >= 9) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2)}');
    }
    if (raw.contains('-')) variants.add(raw.replaceAll('-', ''));
    return variants.toList();
  }

  /// Essaie de résoudre un code scanné vers un véhicule.
  ///
  /// Retourne `{'id': int, 'immatriculation': String}` si un QR code ou un
  /// véhicule correspond, sinon `null`.
  Future<Map<String, dynamic>?> resolve(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return null;

    for (final variant in [trimmed, ...immatVariants(trimmed)]) {
      final r = await _qrSvc.scan(variant);
      if (r != null && r['vehicule'] != null) {
        final v = r['vehicule'] as Map<String, dynamic>;
        return {'id': v['id'], 'immatriculation': v['immatriculation']};
      }
      final veh = await _vehicleSvc.getByImmat(variant);
      if (veh != null) {
        return {'id': veh['id'], 'immatriculation': veh['immatriculation']};
      }
    }
    return null;
  }
}
