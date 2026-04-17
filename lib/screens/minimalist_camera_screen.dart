import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibe_orbit/services/pulse_photo_storage.dart';

/// Full-screen capture: preview + shutter only (close via edge swipe / X minimal).
class MinimalistCameraScreen extends StatefulWidget {
  const MinimalistCameraScreen({super.key, required this.pulseId});

  final String pulseId;

  @override
  State<MinimalistCameraScreen> createState() => _MinimalistCameraScreenState();
}

class _MinimalistCameraScreenState extends State<MinimalistCameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializing = false;
      _error = 'Camera capture is not available on web.';
      return;
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'No camera found on this device.';
          });
        }
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Could not open camera.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onShutter() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      HapticFeedback.mediumImpact();
      final shot = await c.takePicture();
      final saved = await saveThemedPulsePhoto(
        capture: shot,
        pulseId: widget.pulseId,
      );
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save photo. Try again.')),
        );
        setState(() => _capturing = false);
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capture failed.')),
        );
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else if (_initializing)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF448AFF),
                strokeWidth: 2,
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _error ?? 'Camera unavailable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                onPressed: () => Navigator.of(context).pop<String>(null),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: _ShutterButton(
                  enabled:
                      !_initializing && _error == null && _controller != null,
                  busy: _capturing,
                  onTap: _onShutter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled && !busy ? onTap : null,
        child: Ink(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
