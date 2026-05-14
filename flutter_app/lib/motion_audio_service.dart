import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'constants.dart';
import 'models.dart';

/// Context-Aware Motion Detection Service
/// Detects walking/driving via accelerometer and auto-switches to audio-only mode.
/// When motion is detected, it plays audio summaries hands-free.
class MotionAudioService {
  static final MotionAudioService _instance = MotionAudioService._internal();
  factory MotionAudioService() => _instance;
  MotionAudioService._internal();

  StreamSubscription? _accelSubscription;
  final AudioPlayer _player = AudioPlayer();
  
  bool _isMotionDetected = false;
  bool _isAudioMode = false;
  bool _isPlaying = false;
  double _motionMagnitude = 0.0;
  
  // Motion detection thresholds
  static const double _walkingThreshold = 12.0;  // m/s² magnitude for walking
  static const int _motionWindowMs = 2000;       // 2 seconds of sustained motion
  
  DateTime? _motionStartTime;
  final List<double> _recentMagnitudes = [];
  
  // Callbacks
  Function(bool isMotion, double magnitude)? onMotionChanged;
  Function(bool isAudioMode)? onAudioModeChanged;
  Function(String message)? onStatusMessage;

  bool get isMotionDetected => _isMotionDetected;
  bool get isAudioMode => _isAudioMode;
  bool get isPlaying => _isPlaying;
  double get motionMagnitude => _motionMagnitude;

  /// Start listening to accelerometer
  void startMonitoring() {
    _accelSubscription?.cancel();
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((event) {
      _processMotion(event.x, event.y, event.z);
    });
    onStatusMessage?.call("Motion sensor active");
  }

  /// Stop monitoring
  void stopMonitoring() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _isMotionDetected = false;
    _isAudioMode = false;
    _player.stop();
  }

  void _processMotion(double x, double y, double z) {
    // Calculate magnitude (removing gravity ~9.8)
    final magnitude = sqrt(x * x + y * y + z * z);
    _motionMagnitude = magnitude;
    
    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > 10) _recentMagnitudes.removeAt(0);
    
    // Average magnitude over recent samples
    final avgMagnitude = _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
    
    // Detect sustained motion (not just a single bump)
    final isMoving = avgMagnitude > _walkingThreshold;
    
    if (isMoving && !_isMotionDetected) {
      if (_motionStartTime == null) {
        _motionStartTime = DateTime.now();
      } else if (DateTime.now().difference(_motionStartTime!).inMilliseconds > _motionWindowMs) {
        // Sustained motion detected!
        _isMotionDetected = true;
        _isAudioMode = true;
        onMotionChanged?.call(true, avgMagnitude);
        onAudioModeChanged?.call(true);
        onStatusMessage?.call("Motion detected — switching to audio mode");
      }
    } else if (!isMoving && _isMotionDetected) {
      // Motion stopped
      _motionStartTime = null;
      _isMotionDetected = false;
      // Keep audio mode for a bit after stopping
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isMotionDetected) {
          _isAudioMode = false;
          onAudioModeChanged?.call(false);
          onStatusMessage?.call("Stationary — visual mode restored");
        }
      });
      onMotionChanged?.call(false, avgMagnitude);
    } else if (!isMoving) {
      _motionStartTime = null;
    }
  }

  /// Play audio summaries for a list of topics (hands-free mode)
  Future<void> playTopicQueue(List<Topic> topics) async {
    if (topics.isEmpty) return;
    _isPlaying = true;
    
    for (final topic in topics) {
      if (!_isPlaying) break;
      try {
        onStatusMessage?.call("Playing: ${topic.topicName}");
        await _player.play(UrlSource('${AppConstants.backendUrl}/audio/${topic.id}'));
        // Wait for completion
        await _player.onPlayerComplete.first;
        // Brief pause between topics
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        // Skip on error
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    _isPlaying = false;
    onStatusMessage?.call("Audio queue complete");
  }

  /// Stop current playback
  void stopPlayback() {
    _isPlaying = false;
    _player.stop();
  }

  void dispose() {
    stopMonitoring();
    _player.dispose();
  }
}
