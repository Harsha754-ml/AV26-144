import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'constants.dart';

/// Audio Service - tries backend gTTS MP3 first, falls back to on-device TTS
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _ttsInitialized = true;
  }

  /// Play audio for a flashcard - uses on-device TTS (always works)
  Future<void> playForCard(String cardId, {String? fallbackText}) async {
    if (fallbackText != null && fallbackText.isNotEmpty) {
      await speakText(fallbackText);
    }
  }

  /// Speak text directly using on-device TTS
  Future<void> speakText(String text) async {
    await _initTts();
    await _tts.speak(text);
  }

  /// Stop any playing audio
  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  void dispose() {
    _player.dispose();
    _tts.stop();
  }
}
