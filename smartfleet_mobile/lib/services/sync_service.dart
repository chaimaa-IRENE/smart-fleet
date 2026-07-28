import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../database/dao/sync_dao.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncService extends ChangeNotifier {
  final SyncDao _syncDao = SyncDao();
  final Connectivity _connectivity = Connectivity();
  SyncStatus _status = SyncStatus.idle;
  StreamSubscription? _connectivitySub;
  bool _enabled = true;
  int _pendingCount = 0;
  String? _lastSyncDate;

  SyncStatus get status => _status;
  bool get isOnline => _status != SyncStatus.offline;
  int get pendingCount => _pendingCount;
  String? get lastSyncDate => _lastSyncDate;
  bool get enabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('sync_enabled') ?? true;
    _lastSyncDate = prefs.getString('last_sync_date');

    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        _status = SyncStatus.offline;
      } else if (_status == SyncStatus.offline) {
        _status = SyncStatus.idle;
        notifyListeners();
        syncAll();
      }
      notifyListeners();
    });

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _status = SyncStatus.offline;
    }

    await refreshPendingCount();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_enabled', value);
    notifyListeners();
  }

  Future<void> refreshPendingCount() async {
    _pendingCount = await _syncDao.pendingCount();
    notifyListeners();
  }

  Future<void> syncAll() async {
    if (!_enabled || _status == SyncStatus.offline) return;

    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      final pending = await _syncDao.getPending();
      for (var item in pending) {
        try {
          await _syncRecord(item);
          await _syncDao.markCompleted(item['id'] as int);
        } catch (e) {
          debugPrint('Sync failed for record ${item['id']}: $e');
          await _syncDao.markFailed(item['id'] as int);
        }
      }

      final now = DateTime.now().toIso8601String();
      _lastSyncDate = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_date', now);

      _status = SyncStatus.idle;
    } catch (e) {
      _status = SyncStatus.error;
      debugPrint('Sync error: $e');
    }

    await refreshPendingCount();
    notifyListeners();
  }

  Future<void> _syncRecord(Map<String, dynamic> record) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/${record['tableName']}/${record['action'] == 'DELETE' ? '${record['recordId']}' : ''}',
      );
      final method = record['action'] == 'DELETE'
          ? 'DELETE'
          : record['action'] == 'INSERT'
              ? 'POST'
              : 'PUT';

      final body = record['payload'] != null
          ? jsonDecode(record['payload'] as String)
          : null;

      final response = await http.Client()
          .send(
            http.Request(method, uri)
              ..headers['Content-Type'] = 'application/json'
              ..body = body != null ? jsonEncode(body) : '',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      // If server is unreachable, just skip — data stays local
      debugPrint('Endpoint unreachable: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
