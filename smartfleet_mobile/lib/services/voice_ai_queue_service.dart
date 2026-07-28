import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class VoiceAiQueueService {
  static Database? _db;
  static bool _processing = false;
  static Timer? _retryTimer;

  static Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'voice_ai_queue.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_declarations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            body TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending'
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> enqueue(Map<String, dynamic> body) async {
    final db = await _getDb();
    await db.insert('pending_declarations', {
      'body': jsonEncode(body),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'status': 'pending',
    });
    processQueue();
  }

  static Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;

    try {
      final db = await _getDb();
      final rows = await db.query('pending_declarations',
          where: 'status = ?', whereArgs: ['pending'],
          orderBy: 'created_at ASC');

      for (final row in rows) {
        final id = row['id'] as int;
        final body = jsonDecode(row['body'] as String) as Map<String, dynamic>;
        final retryCount = row['retry_count'] as int;

        if (retryCount >= 5) {
          await db.update('pending_declarations',
              {'status': 'failed'}, where: 'id = ?', whereArgs: [id]);
          continue;
        }

        try {
          final res = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/declarations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200 || res.statusCode == 201) {
            await db.delete('pending_declarations',
                where: 'id = ?', whereArgs: [id]);
          } else {
            await db.update('pending_declarations',
                {'retry_count': retryCount + 1},
                where: 'id = ?', whereArgs: [id]);
          }
        } catch (_) {
          await db.update('pending_declarations',
              {'retry_count': retryCount + 1},
              where: 'id = ?', whereArgs: [id]);
          _startRetryTimer();
          _processing = false;
          return;
        }
      }
    } finally {
      _processing = false;
    }
  }

  static void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 15), () {
      processQueue();
    });
  }

  static Future<int> getPendingCount() async {
    final db = await _getDb();
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM pending_declarations WHERE status = ?',
        ['pending']);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getPendingItems() async {
    final db = await _getDb();
    return await db.query('pending_declarations',
        where: 'status = ?', whereArgs: ['pending'],
        orderBy: 'created_at ASC');
  }

  static void dispose() {
    _retryTimer?.cancel();
    _db?.close();
    _db = null;
  }
}
