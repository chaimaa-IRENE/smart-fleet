import 'dart:math' as math;
import '../database_helper.dart';

class TrackingDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> update(Map<String, dynamic> data) async {
    final db = await _db.database;
    final id = await db.insert('tracking_history', data);
    await db.update(
      'vehicules',
      {
        'derniereLatitude': data['latitude'],
        'derniereLongitude': data['longitude'],
        'derniereVitesse': data['vitesse'] ?? 0,
        'derniereIgnition': data['ignition'] ?? 0,
      },
      where: 'immatriculation = ?',
      whereArgs: [data['immatriculation']],
    );
    return id;
  }

  Future<Map<String, dynamic>?> getLatest(String immatriculation) async {
    final db = await _db.database;
    final r = await db.query(
      'tracking_history',
      where: 'immatriculation = ?',
      whereArgs: [immatriculation],
      orderBy: 'dateTracking DESC',
      limit: 1,
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllLatest() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT t.* FROM tracking_history t
      INNER JOIN (
        SELECT immatriculation, MAX(dateTracking) as maxDate
        FROM tracking_history GROUP BY immatriculation
      ) latest ON t.immatriculation = latest.immatriculation
      AND t.dateTracking = latest.maxDate
    ''');
  }

  Future<List<Map<String, dynamic>>> getHistory(
    String immatriculation, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    String where = 'immatriculation = ?';
    List<dynamic> args = [immatriculation];
    if (from != null) {
      where += ' AND dateTracking >= ?';
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where += ' AND dateTracking <= ?';
      args.add(to.toIso8601String());
    }
    return await db.query(
      'tracking_history',
      where: where,
      whereArgs: args,
      orderBy: 'dateTracking ASC',
    );
  }

  Future<Map<String, dynamic>> getAnalytics(String immatriculation) async {
    final history = await getHistory(immatriculation);
    double maxSpeed = 0;
    double avgSpeed = 0;
    double totalSpeed = 0;
    int ignitionOnCount = 0;
    for (var h in history) {
      final speed = (h['vitesse'] as num?)?.toDouble() ?? 0;
      totalSpeed += speed;
      if (speed > maxSpeed) maxSpeed = speed;
      if ((h['ignition'] as int?) == 1) ignitionOnCount++;
    }
    avgSpeed = history.isNotEmpty ? totalSpeed / history.length : 0;
    double distance = 0;
    for (int i = 1; i < history.length; i++) {
      final lat1 = (history[i - 1]['latitude'] as num).toDouble();
      final lon1 = (history[i - 1]['longitude'] as num).toDouble();
      final lat2 = (history[i]['latitude'] as num).toDouble();
      final lon2 = (history[i]['longitude'] as num).toDouble();
      distance += _haversine(lat1, lon1, lat2, lon2);
    }
    return {
      'distance': distance,
      'maxSpeed': maxSpeed,
      'avgSpeed': avgSpeed,
      'ignitionOnCount': ignitionOnCount,
      'pointsCount': history.length,
    };
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return R * 2 * math.asin(math.sqrt(a));
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);
}
