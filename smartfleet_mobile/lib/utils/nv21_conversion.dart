import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Convertit une image caméra `yuv420` (3 plans) en tableau NV21 attendu par
/// MLKit pour une détection temps réel des codes-barres.
Uint8List? convertYuv420ToNv21(CameraImage image) {
  if (image.planes.length < 3) return null;
  final width = image.width;
  final height = image.height;
  final y = image.planes[0];
  final u = image.planes[1];
  final v = image.planes[2];

  final uvWidth = u.width ?? width ~/ 2;
  final uvHeight = u.height ?? height ~/ 2;
  final out = Uint8List(width * height + uvWidth * uvHeight * 2);
  var idx = 0;

  // Plan luma (Y), ligne par ligne (gère le padding de bytesPerRow).
  final yBytes = y.bytes;
  final yStride = y.bytesPerRow;
  for (var row = 0; row < height; row++) {
    out.setRange(idx, idx + width, yBytes, row * yStride);
    idx += width;
  }

  // Chroma entrelacé V,U (NV21). L'ordre U/V n'a pas d'impact sur le
  // décodage des codes-barres (contraste basé sur la luminance).
  final uBytes = u.bytes;
  final vBytes = v.bytes;
  final uStride = u.bytesPerRow;
  final vStride = v.bytesPerRow;
  final uStep = u.bytesPerPixel ?? 1;
  final vStep = v.bytesPerPixel ?? 1;
  for (var row = 0; row < uvHeight; row++) {
    final uRow = row * uStride;
    final vRow = row * vStride;
    for (var col = 0; col < uvWidth; col++) {
      out[idx++] = vBytes[vRow + col * vStep];
      out[idx++] = uBytes[uRow + col * uStep];
    }
  }
  return out;
}

/// Mappe un angle en degrés vers la rotation MLKit.
InputImageRotation rotationFromDegrees(int deg) {
  switch (deg) {
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    case 270:
      return InputImageRotation.rotation270deg;
    default:
      return InputImageRotation.rotation0deg;
  }
}
