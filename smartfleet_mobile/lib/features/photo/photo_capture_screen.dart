import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../widgets/premium/glass_card.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  CameraController? _controller;
  List<File> _capturedPhotos = [];
  bool _isReady = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _controller = CameraController(cameras.first, ResolutionPreset.high);
      await _controller!.initialize();
      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final file = await _controller!.takePicture();
      if (mounted) {
        setState(() => _capturedPhotos.insert(0, File(file.path)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo capturée'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Photo error: $e');
    }
  }

  void _toggleTorch() {
    _controller?.setFlashMode(_isTorchOn ? FlashMode.off : FlashMode.torch);
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Capture photo'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
          if (_capturedPhotos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => setState(() => _capturedPhotos.clear()),
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: _isReady && _controller != null
                ? CameraPreview(_controller!)
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('Initialisation caméra...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            color: Colors.black,
            child: Column(
              children: [
                FloatingActionButton.large(
                  onPressed: _takePhoto,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                ),
                const SizedBox(height: 8),
                Text('Prendre une photo',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (_capturedPhotos.isNotEmpty)
            Container(
              height: 100,
              color: Colors.black,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _capturedPhotos.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: GestureDetector(
                    onTap: () => _showPhotoPreview(context, _capturedPhotos[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_capturedPhotos[i],
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPhotoPreview(BuildContext context, File photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(photo, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _capturedPhotos.remove(photo));
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  label: const Text('Fermer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
