import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SignaturePad extends StatefulWidget {
  final double height;
  final Color penColor;
  final double penWidth;

  const SignaturePad({
    super.key,
    this.height = 200,
    this.penColor = Colors.black,
    this.penWidth = 3.0,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final _containerKey = GlobalKey();

  void _onPointerDown(PointerDownEvent e) {
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.globalToLocal(e.position);
    _currentStroke = [pos];
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_currentStroke.isEmpty) return;
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.globalToLocal(e.position);
    _currentStroke.add(pos);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
      setState(() {});
    }
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
  }

  Future<String?> toBase64Png() async {
    if (_strokes.every((s) => s.isEmpty)) return null;
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;
    if (size == Size.zero) return null;
    const scale = 3.0;
    final w = (size.width * scale).round();
    final h = (size.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = widget.penColor
      ..strokeWidth = widget.penWidth * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx * scale, stroke.first.dy * scale);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx * scale, stroke[i].dy * scale);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(Uint8List.view(byteData.buffer));
  }

  bool get hasSignature => _strokes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Container(
        key: _containerKey,
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: CustomPaint(
              painter: _SignaturePainter(
                strokes: _strokes,
                currentStroke: _currentStroke,
                penColor: widget.penColor,
                penWidth: widget.penWidth,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color penColor;
  final double penWidth;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.penColor,
    required this.penWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeWidth = penWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.length < 2) return;
    final path = Path();
    path.moveTo(stroke.first.dx, stroke.first.dy);
    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final _key = GlobalKey<_SignaturePadState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Signez pour valider le check-up',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirmez que l\'inspection a été réalisée',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SignaturePad(key: _key, height: 180),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _key.currentState?.clear(),
                    child: const Text('Effacer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final sig = _key.currentState;
                      if (sig == null || !sig.hasSignature) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Veuillez signer en dessinant sur la zone ci-dessus'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      sig.toBase64Png().then((b64) {
                        if (mounted) Navigator.pop(context, b64);
                      });
                    },
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
