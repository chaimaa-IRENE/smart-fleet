import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Harnais de test autonome (widget) :
/// 1. Décode toutes les images de `files/bctest/` avec ML Kit
///    (`InputImage.fromFilePath`).
/// 2. Vérifie que le flux caméra (`startImageStream`) délivre des frames.
/// 3. Vérifie le mode photo réellement utilisé par l'app : préview montée puis
///    `takePicture` → décodage du fichier JPEG.
///
/// Écrit le résultat dans `files/selftest_results.txt`.
/// Lancement : `flutter run -t lib/dev/barcode_selftest.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SelftestApp());
}

class _SelftestApp extends StatefulWidget {
  const _SelftestApp();

  @override
  State<_SelftestApp> createState() => _SelftestAppState();
}

class _SelftestAppState extends State<_SelftestApp> {
  final List<String> _lines = [];
  CameraController? _camera;
  bool _busy = true;
  String _status = 'Démarrage...';

  void _log(String s) {
    _lines.add(s);
    debugPrint('[SELFTEST] $s');
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    _log('----- Étape 1 : décodage des images de test -----');
    await _runImageTests();

    _log('----- Étape 2 : flux caméra continu (startImageStream) -----');
    await _runStreamTests();

    _log('----- Étape 3 : mode photo (takePicture + décodage JPEG) -----');
    await _runPhotoTest();

    final support = await getApplicationSupportDirectory();
    final outFile = File('${support.path}/selftest_results.txt');
    outFile.writeAsStringSync(_lines.join('\n'));
    debugPrint('[SELFTEST] écriture: ${outFile.path}');
    exit(0);
  }

  Future<void> _runImageTests() async {
    final support = await getApplicationSupportDirectory();
    final folder = Directory('${support.path}/bctest');
    _log('folder=${folder.path} exists=${folder.existsSync()}');

    final files = folder.existsSync()
        ? folder
            .listSync()
            .whereType<File>()
            .where((f) {
              final p = f.path.toLowerCase();
              return p.endsWith('.png') ||
                  p.endsWith('.jpg') ||
                  p.endsWith('.jpeg');
            })
            .toList()
        : <File>[];
    _log('images=${files.length}');

    final scanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    for (final f in files) {
      final name = f.path.split(Platform.pathSeparator).last;
      try {
        final input = InputImage.fromFilePath(f.path);
        final barcodes = await scanner.processImage(input);
        final valid =
            barcodes.where((b) => (b.rawValue ?? '').trim().isNotEmpty).toList();
        if (valid.isEmpty) {
          _log('$name => NONE (bruts=${barcodes.length})');
        } else {
          final b = valid.first;
          _log('$name => ${b.format} | ${b.rawValue}');
        }
      } catch (e) {
        _log('$name => ERR $e');
      }
    }
    await scanner.close();
  }

  Future<void> _runStreamTests() async {
    await Future.delayed(const Duration(seconds: 20));
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _log('stream: permission refusée');
      return;
    }
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      _log('stream: availableCameras ERR $e');
      return;
    }
    if (cameras.isEmpty) {
      _log('stream: aucune caméra');
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    for (final preset in const [
      ResolutionPreset.low,
      ResolutionPreset.medium,
      ResolutionPreset.high,
      ResolutionPreset.veryHigh,
      ResolutionPreset.ultraHigh,
      ResolutionPreset.max,
    ]) {
      final cam = CameraController(
        back,
        preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      try {
        await cam.initialize();
      } catch (e) {
        _log('stream(${preset.name}): init ERR $e');
        continue;
      }
      var frames = 0;
      try {
        cam.startImageStream((image) {
          frames++;
        });
        _log('stream(${preset.name}): startImageStream OK');
      } catch (e) {
        _log('stream(${preset.name}): startImageStream ERR $e');
        await cam.dispose();
        continue;
      }
      await Future.delayed(const Duration(seconds: 6));
      _log('stream(${preset.name}): frames en 6s = $frames');
      try {
        await cam.stopImageStream();
      } catch (_) {}
      await cam.dispose();
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _runPhotoTest() async {
    await Future.delayed(const Duration(seconds: 2));
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _log('photo: permission refusée');
      return;
    }
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      _log('photo: availableCameras ERR $e');
      return;
    }
    if (cameras.isEmpty) {
      _log('photo: aucune caméra');
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final configs = <Map<String, Object>>[
      {'cam': cameras.first, 'preset': ResolutionPreset.high, 'label': 'front/high'},
      {'cam': back, 'preset': ResolutionPreset.high, 'label': 'back/high'},
      {'cam': back, 'preset': ResolutionPreset.veryHigh, 'label': 'back/veryHigh'},
    ];

    for (final cfg in configs) {
      final label = cfg['label'] as String;
      final cam = CameraController(
        cfg['cam'] as CameraDescription,
        cfg['preset'] as ResolutionPreset,
        enableAudio: false,
      );
      try {
        await cam.initialize();
        if (!mounted) return;
        setState(() {
          _camera = cam;
          _status = 'photo $label : préview…';
        });
        for (var i = 0; i < 30; i++) {
          if (cam.value.previewSize != null) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }
        await Future.delayed(const Duration(seconds: 2));
        _log('photo($label): previewSize=${cam.value.previewSize} '
            'streaming=${cam.value.isStreamingImages}');

        var ok = false;
        for (var attempt = 1; attempt <= 3; attempt++) {
          try {
            final file = await cam.takePicture();
            final input = InputImage.fromFilePath(file.path);
            final scanner = BarcodeScanner(formats: [BarcodeFormat.all]);
            final barcodes = await scanner.processImage(input);
            _log('photo($label): OK essai $attempt (${await file.length()} octets) '
                'barcodes=${barcodes.length}');
            await scanner.close();
            try {
              File(file.path).deleteSync();
            } catch (_) {}
            ok = true;
            break;
          } catch (e) {
            _log('photo($label): essai $attempt ERR $e');
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        if (!ok) {
          _log('photo($label): ÉCHEC après 3 essais');
        }
      } catch (e) {
        _log('photo($label): init ERR $e');
      } finally {
        await cam.dispose();
        if (mounted) {
          setState(() {
            _camera = null;
            _busy = false;
          });
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: _camera != null
            ? Stack(
                children: [
                  Positioned.fill(child: CameraPreview(_camera!)),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.black54,
                      child: Text(
                        _status,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Text(
                  _busy ? 'Test en cours...' : 'Terminé',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
      ),
    );
  }
}
