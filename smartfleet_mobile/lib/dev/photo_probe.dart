import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Sonde isolée : préview + takePicture + décodage ML Kit, rien d'autre.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  CameraController? _camera;
  String _log = 'init...';

  void _add(String s) {
    debugPrint('[PROBE] $s');
    _log += '\n$s';
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(seconds: 2));
    final status = await Permission.camera.request();
    _add('permission=$status');
    if (!status.isGranted) return;

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      _add('availableCameras ERR $e');
      return;
    }
    _add('cameras=${cameras.map((c) => c.name).toList()}');

    final cam = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await cam.initialize();
    } catch (e) {
      _add('init ERR $e');
      return;
    }
    _add('initialized preset=high');
    if (!mounted) return;
    setState(() {
      _camera = cam;
      _log += '\npréview...';
    });

    for (var i = 0; i < 30; i++) {
      if (cam.value.previewSize != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    await Future.delayed(const Duration(seconds: 2));
    _add('previewSize=${cam.value.previewSize}');

    for (var attempt = 1; attempt <= 4; attempt++) {
      try {
        final file = await cam.takePicture();
        _add('takePicture OK essai $attempt (${await file.length()} octets)');
        final scanner = BarcodeScanner(formats: [BarcodeFormat.all]);
        final barcodes = await scanner.processImage(InputImage.fromFilePath(file.path));
        _add('MLKit barcodes=${barcodes.length}');
        await scanner.close();
        try {
          File(file.path).deleteSync();
        } catch (_) {}
        break;
      } catch (e) {
        _add('essai $attempt ERR $e');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    setState(() => _log += '\nTERMINÉ');
    await cam.dispose();
    debugPrint('[PROBE] FIN');
    exit(0);
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
                  Positioned(
                    top: 40,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.black54,
                      child: Text(
                        _log,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Text(_log, style: const TextStyle(color: Colors.white)),
              ),
      ),
    );
  }
}
