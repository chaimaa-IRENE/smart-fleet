import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../database/dao/biometric_device_dao.dart';

enum BioType { faceId, touchId, fingerprint, iris, none }

class BiometricAuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final BiometricDeviceDao _deviceDao = BiometricDeviceDao();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _biometricUserIdKey = 'biometric_user_id';
  static const _biometricEnabledKey = 'biometric_enabled';

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      if (Platform.isAndroid || Platform.isIOS || Platform.isWindows ||
          Platform.isMacOS) {
        return false;
      }
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<BioType> getBiometricType() async {
    if (kIsWeb) return BioType.none;
    try {
      final available = await _localAuth.getAvailableBiometrics();
      if (available.contains(BiometricType.face)) {
        return BioType.faceId;
      }
      if (available.contains(BiometricType.fingerprint)) {
        return BioType.fingerprint;
      }
      if (available.contains(BiometricType.iris)) {
        return BioType.iris;
      }
      return BioType.touchId;
    } catch (_) {
      return BioType.none;
    }
  }

  Future<bool> authenticate({String reason = 'Authentifiez-vous pour accéder à SmartFleet'}) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithFallback({String reason = 'Authentifiez-vous pour accéder à SmartFleet'}) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> enrollUser(int userId, String deviceName) async {
    final authenticated = await authenticate(
      reason: 'Activez Face ID pour vous connecter sans mot de passe',
    );
    if (!authenticated) return false;

    final deviceId = await _getDeviceId();
    final platform = _getPlatform();

    final existing = await _deviceDao.getByUserId(userId);
    if (existing != null) {
      await _deviceDao.disableByUserId(userId);
    }

    await _deviceDao.insert({
      'userId': userId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'biometricEnabled': 1,
    });

    await _storage.write(key: _biometricUserIdKey, value: userId.toString());
    await _storage.write(key: _biometricEnabledKey, value: 'true');

    return true;
  }

  Future<bool> isBiometricEnabledForUser(int userId) async {
    final enabled = await _storage.read(key: _biometricEnabledKey);
    if (enabled != 'true') return false;
    final storedId = await _storage.read(key: _biometricUserIdKey);
    if (storedId != userId.toString()) return false;
    final device = await _deviceDao.getByUserId(userId);
    return device != null;
  }

  Future<bool> isAnyBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  Future<int?> getBiometricUserId() async {
    final id = await _storage.read(key: _biometricUserIdKey);
    if (id == null) return null;
    return int.tryParse(id);
  }

  Future<void> disableBiometric(int userId) async {
    await _deviceDao.disableByUserId(userId);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _biometricUserIdKey);
  }

  Future<void> disableByDeviceId(int deviceId) async {
    await _deviceDao.disable(deviceId);
    final device = await _getDeviceById(deviceId);
    if (device != null) {
      final storedId = await _storage.read(key: _biometricUserIdKey);
      if (storedId == device['userId'].toString()) {
        await _storage.delete(key: _biometricEnabledKey);
        await _storage.delete(key: _biometricUserIdKey);
      }
    }
  }

  Future<Map<String, dynamic>?> _getDeviceById(int id) async {
    final db = _deviceDao;
    final devices = await db.getAllWithUsers();
    for (final d in devices) {
      if (d['id'] == id) return d;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRegisteredDevices(int userId) async {
    return await _deviceDao.getAllByUserId(userId);
  }

  Future<List<Map<String, dynamic>>> getAllBiometricUsers() async {
    return await _deviceDao.getAllWithUsers();
  }

  Future<int> getActiveDeviceCount() async {
    return await _deviceDao.countEnabled();
  }

  Future<void> revokeAllDevices(int userId) async {
    await _deviceDao.disableByUserId(userId);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _biometricUserIdKey);
  }

  Future<String> _getDeviceId() async {
    try {
      if (kIsWeb) return 'web-${DateTime.now().millisecondsSinceEpoch}';
      if (Platform.isAndroid) {
        return 'android-${DateTime.now().millisecondsSinceEpoch}';
      }
      if (Platform.isIOS) {
        return 'ios-${DateTime.now().millisecondsSinceEpoch}';
      }
      if (Platform.isWindows) {
        return 'windows-${DateTime.now().millisecondsSinceEpoch}';
      }
      return 'device-${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      return 'device-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }

  Future<void> clearAllBiometricData() async {
    await _storage.delete(key: _biometricUserIdKey);
    await _storage.delete(key: _biometricEnabledKey);
  }
}
