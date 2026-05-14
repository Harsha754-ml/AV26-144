import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models.dart';
import 'constants.dart';
import 'api_service.dart';

/// Learning Flow Screen
/// Flow: Audio Overview → Random Quiz → Result
class LearningFlowScreen extends StatefulWidget {
  final Topic flashcard;
  const LearningFlowScreen({Key? key, required this.flashcard}) : super(key: key);

  @override
  _LearningFlowScreenState createState() => _LearningFlowScreenState();
}

class _LearningFlowScreenState extends State<LearningFlowScreen> {
  String _stage = 'audio'; // audio, quiz, type, result
  bool _audioPlaying = false;
  bool _showAnswer = false;
  String? _quizResult;
  String _typeAnswer = '';
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _typeCtrl = TextEditingController();
  late String _gameType;

  @override
  void initState() {
    super.initState();
    _gameType = Random().nextBool() ? 'quiz' : 'type';
    _startAudio();
  }

  @override
  void dispose() {
    _player.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _startAudio() async {
    setState(() => _audioPlaying = true);
    try {
      await _player.play(UrlSource('${AppConstants.backendUrl}/audio/${widget.flashcard.id}'));
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _audioPlaying = false);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) setState(() => _stage = _gameType);
          });
        }
      });
    } catch (e) {
      // If audio fails, skip to quiz
      setState(() { _audioPlaying = false; _stage = _gameType; });
    }
  }

  void _skipAudio() {
    _player.stop();
    setState(() { _audioPlaying = false; _stage = _gameType; });
  }

  void _handleResult(String result) {
    setState(() { _quizResult = result; _stage = 'result'; });
    ApiService.reviewFlashcard(widget.flashcard.id, result);
  }

  void _handleTypeSubmit() {
    final similarity = _calcSimilarity(_typeCtrl.text, widget.flashcard.answer);
    final result = similarity >= 40 ? 'remembered' : 'forgot';
    setState(() { _quizResult = result; _showAnswer = true; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _stage = 'result');
    });
    ApiService.reviewFlashcard(widget.flashcard.id, result);
  }

  int _calcSimilarity(String input, String answer) {
    final aWords = input.toLowerCase().trim().split(RegExp(r'\s+')).toSet();
    final bWords = answer.toLowerCase().trim().split(RegExp(r'\s+')).toSet();
    if (aWords.isEmpty || bWords.isEmpty) return 0;
    return ((aWords.intersection(bWords).length / bWords.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        title: const Text("Learning Session", style: TextStyle(fontFamily: 'serif', color: Color(0xFFC5A059), fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.flashcard.topicName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFC5A059))),
                  const SizedBox(height: 6),
                  Text(widget.flashcard.question, style: const TextStyle(fontSize: 16, fontFamily: 'serif', color: Colors.white, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stage content
            Expanded(child: _buildStage()),

            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(_stage == 'audio'),
                const SizedBox(width: 8),
                _dot(_stage == 'quiz' || _stage == 'type'),
                const SizedBox(width: 8),
                _dot(_stage == 'result'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFFC5A059) : Colors.white12));

  Widget _buildStage() {
    switch (_stage) {
      case 'audio': return _buildAudioStage();
      case 'quiz': return _buildQuizStage();
      case 'type': return _buildTypeStage();
      case 'result': return _buildResultStage();
      default: return const SizedBox();
    }
  }

  Widget _buildAudioStage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _audioPlaying ? const Color(0xFFC5A059).withAlpha(40) : Colors.white10,
              border: Border.all(color: _audioPlaying ? const Color(0xFFC5A059) : Colors.white10, width: 2),
            ),
            child: Icon(Icons.volume_up, size: 40, color: _audioPlaying ? const Color(0xFFC5A059) : Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(_audioPlaying ? "Listening to overview..." : "Preparing audio...", style: const TextStyle(color: Color(0xFF8DA290), fontStyle: FontStyle.italic, fontSize: 16)),
          const SizedBox(height: 8),
          const Text("Quiz starts after audio", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 30),
          if (_audioPlaying)
            TextButton(onPressed: _skipAudio, child: const Text("Skip to Quiz →", style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildQuizStage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, size: 50, color: Color(0xFFC5A059)),
          const SizedBox(height: 16),
          const Text("Do you remember?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
          const SizedBox(height: 24),
          if (!_showAnswer)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: () => setState(() => _showAnswer = true),
              child: const Text("REVEAL ANSWER", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF8DA290).withAlpha(20), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8DA290).withAlpha(80))),
              child: Text(widget.flashcard.answer, style: const TextStyle(color: Color(0xFF8DA290), fontFamily: 'serif', fontStyle: FontStyle.italic), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8DA290), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleResult('remembered'), child: const Text("GOT IT"))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleResult('forgot'), child: const Text("FORGOT"))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeStage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.keyboard, size: 40, color: Color(0xFFC5A059)),
        const SizedBox(height: 12),
        const Text("Type from memory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        if (_showAnswer)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF8DA290).withAlpha(20), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF8DA290).withAlpha(80))),
            child: Text(widget.flashcard.answer, style: const TextStyle(color: Color(0xFF8DA290), fontSize: 13, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          )
        else ...[
          TextField(controller: _typeCtrl, maxLines: 3, decoration: InputDecoration(hintText: "Type your answer...", hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF0F0F11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: _typeCtrl.text.trim().isNotEmpty ? _handleTypeSubmit : null, child: const Text("SUBMIT", style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ],
    );
  }

  Widget _buildResultStage() {
    final won = _quizResult == 'remembered';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(won ? Icons.emoji_events : Icons.refresh, size: 60, color: won ? const Color(0xFF8DA290) : Colors.redAccent),
          const SizedBox(height: 16),
          Text(won ? "Well Done!" : "Keep Practicing", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
          const SizedBox(height: 8),
          Text(won ? "Stability boosted." : "You'll see this again sooner.", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: () => Navigator.pop(context), child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
