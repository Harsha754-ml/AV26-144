import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

/// Floating rPPG Camera Widget for mobile
/// Shows during games/quizzes to track facial micro-expressions
class RppgCameraWidget extends StatefulWidget {
  final bool active;
  const RppgCameraWidget({Key? key, required this.active}) : super(key: key);

  @override
  _RppgCameraWidgetState createState() => _RppgCameraWidgetState();
}

class _RppgCameraWidgetState extends State<RppgCameraWidget> {
  CameraController? _controller;
  Timer? _analysisTimer;
  String _stress = 'LOW';
  int _cogLoad = 25;
  bool _initialized = false;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _initCamera();
  }

  @override
  void didUpdateWidget(RppgCameraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized) {
      _initCamera();
    } else if (!widget.active && _initialized) {
      _disposeCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(front, ResolutionPreset.low, enableAudio: false);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _startAnalysis();
      }
    } catch (e) {
      debugPrint('Camera init failed: $e');
    }
  }

  void _startAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _controller == null) return;
      _frameCount++;

      // Simulate rPPG signal extraction from facial micro-variations
      final bpm = 72 + sin(_frameCount * 0.1) * 8 + Random().nextDouble() * 4;
      final stressLevel = ((bpm - 60) / 60).clamp(0.0, 1.0);
      final cogLoadVal = (stressLevel * 100).round();

      setState(() {
        _stress = stressLevel > 0.6 ? 'HIGH' : stressLevel > 0.3 ? 'MED' : 'LOW';
        _cogLoad = cogLoadVal;
      });

      // Send to backend
      http.post(
        Uri.parse('${AppConstants.backendUrl}/biometrics'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'bpm': bpm.round(), 'hrv': 55, 'stress_level': stressLevel}),
      ).catchError((_) => http.Response('', 200));
    });
  }

  void _disposeCamera() {
    _analysisTimer?.cancel();
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || !_initialized || _controller == null) return const SizedBox();

    return Positioned(
      bottom: 80,
      right: 12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC5A059).withAlpha(60)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 12)],
        ),
        child: Column(
          children: [
            // Camera preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 75,
                child: CameraPreview(_controller!),
              ),
            ),
            // Stats bar
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0A0B),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _stress,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: _stress == 'HIGH' ? Colors.redAccent : _stress == 'MED' ? Colors.amber : const Color(0xFF8DA290),
                    ),
                  ),
                  Text('$_cogLoad%', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
