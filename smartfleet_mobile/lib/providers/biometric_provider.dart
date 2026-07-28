import 'package:flutter/foundation.dart';
import '../services/biometric_auth_service.dart';

enum BiometricStatus { unavailable, available, enrolled, notEnrolled }

class BiometricProvider extends ChangeNotifier {
  final BiometricAuthService _service;
  BiometricStatus _status = BiometricStatus.unavailable;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _allBiometricUsers = [];
  int _activeDeviceCount = 0;
  bool _loading = false;

  BiometricProvider(this._service);

  BiometricStatus get status => _status;
  List<Map<String, dynamic>> get devices => _devices;
  List<Map<String, dynamic>> get allBiometricUsers => _allBiometricUsers;
  int get activeDeviceCount => _activeDeviceCount;
  bool get loading => _loading;

  Future<void> init() async {
    final available = await _service.isAvailable();
    if (!available) {
      _status = BiometricStatus.unavailable;
      notifyListeners();
      return;
    }
    final anyEnabled = await _service.isAnyBiometricEnabled();
    _status = anyEnabled ? BiometricStatus.enrolled : BiometricStatus.notEnrolled;
    notifyListeners();
  }

  Future<bool> checkForUser(int userId) async {
    final enabled = await _service.isBiometricEnabledForUser(userId);
    if (enabled) {
      _status = BiometricStatus.enrolled;
    } else {
      _status = BiometricStatus.notEnrolled;
    }
    notifyListeners();
    return enabled;
  }

  Future<bool> authenticate() async {
    return await _service.authenticate();
  }

  Future<bool> enroll(int userId, String deviceName) async {
    _loading = true;
    notifyListeners();
    final result = await _service.enrollUser(userId, deviceName);
    if (result) {
      _status = BiometricStatus.enrolled;
    }
    _loading = false;
    notifyListeners();
    return result;
  }

  Future<void> loadDevices(int userId) async {
    _devices = await _service.getRegisteredDevices(userId);
    notifyListeners();
  }

  Future<void> loadAllBiometricUsers() async {
    _allBiometricUsers = await _service.getAllBiometricUsers();
    _activeDeviceCount = await _service.getActiveDeviceCount();
    notifyListeners();
  }

  Future<void> disableBiometric(int userId) async {
    await _service.disableBiometric(userId);
    _status = BiometricStatus.notEnrolled;
    _devices = [];
    notifyListeners();
  }

  Future<void> removeDevice(int deviceId, int userId) async {
    await _service.disableByDeviceId(deviceId);
    await loadDevices(userId);
  }

  Future<void> revokeAllDevices(int userId) async {
    await _service.revokeAllDevices(userId);
    _status = BiometricStatus.notEnrolled;
    _devices = [];
    notifyListeners();
  }

  Future<void> adminDisableRemote(int userId) async {
    await _service.revokeAllDevices(userId);
    await loadAllBiometricUsers();
  }
}
