import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'api_service.dart';

// ============================================================
// DEMO DATA - Always available for showcase
// ============================================================
final List<Topic> _demoFlashcards = [
  Topic(id: "d1", topicName: "Philosophy: Stoicism", question: "What is the 'Dichotomy of Control' as defined by Epictetus?", answer: "The distinction between things within our power (our judgments, intentions) and things not in our power (external events, others' actions).", sourceType: "demo"),
  Topic(id: "d2", topicName: "Quantum Mechanics", question: "Define the Heisenberg Uncertainty Principle.", answer: "It is impossible to simultaneously know both the exact position and exact momentum of a particle with arbitrary precision.", sourceType: "demo"),
  Topic(id: "d3", topicName: "React Performance", question: "When should useMemo be preferred over simple memoization?", answer: "When a computation is expensive and its dependencies change infrequently, preventing unnecessary recalculations on every render.", sourceType: "demo"),
  Topic(id: "d4", topicName: "Growth Strategy", question: "Explain the AARRR (Pirate Metrics) framework.", answer: "Acquisition, Activation, Retention, Revenue, Referral — a funnel for measuring SaaS growth at each stage of the user lifecycle.", sourceType: "demo"),
  Topic(id: "d5", topicName: "Neuroscience", question: "What role does the hippocampus play in memory?", answer: "It consolidates short-term memories into long-term memories and is critical for spatial navigation and episodic memory formation.", sourceType: "demo"),
  Topic(id: "d6", topicName: "Distributed Systems", question: "What is the Saga Pattern used for?", answer: "Managing data consistency across microservices by breaking a transaction into a sequence of local transactions with compensating actions for rollback.", sourceType: "demo"),
  Topic(id: "d7", topicName: "Machine Learning", question: "What is the bias-variance tradeoff?", answer: "Bias is error from oversimplified models (underfitting); variance is error from over-complex models (overfitting). The goal is to minimize both.", sourceType: "demo"),
  Topic(id: "d8", topicName: "Operating Systems", question: "What is a deadlock?", answer: "A state where two or more processes are blocked forever, each waiting for a resource held by the other, forming a circular dependency.", sourceType: "demo"),
];

// ============================================================
// OFFLINE-FIRST SYNC QUEUE
// Games always work. Results queue locally and sync when server is up.
// ============================================================
class _GameSyncQueue {
  static const _storageKey = 'game_results_queue';
  static Timer? _syncTimer;

  /// Queue results locally (always succeeds, no server needed)
  static Future<void> queueResults(List<Map<String, String>> results) async {
    if (results.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_storageKey) ?? [];
    for (final r in results) {
      existing.add(json.encode(r));
    }
    await prefs.setStringList(_storageKey, existing);
    // Try immediate sync
    _attemptSync();
  }

  /// Try to sync queued results to server
  static Future<void> _attemptSync() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_storageKey) ?? [];
    if (queue.isEmpty) return;

    final synced = <String>[];
    for (final item in queue) {
      try {
        final r = json.decode(item) as Map<String, dynamic>;
        await ApiService.reviewFlashcard(r['id']!, r['result']!);
        synced.add(item);
      } catch (_) {
        // Server unreachable — stop trying, will retry later
        break;
      }
    }

    if (synced.isNotEmpty) {
      final remaining = queue.where((item) => !synced.contains(item)).toList();
      await prefs.setStringList(_storageKey, remaining);
      debugPrint("✅ Synced ${synced.length} game results. ${remaining.length} remaining.");
    }
  }

  /// Start background sync timer (call once on app start)
  static void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _attemptSync());
  }

  /// Get count of pending unsynced results
  static Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? []).length;
  }
}

/// Send game results — queues offline, syncs when connected
Future<void> _sendGameResults(List<Map<String, String>> results) async {
  await _GameSyncQueue.queueResults(results);
}

/// Call this from main.dart to start background sync
void startGameSyncService() {
  _GameSyncQueue.startPeriodicSync();
}

// ============================================================
// MAIN GAME SCREEN - 4 Games with Tab Navigation
// ============================================================
class GameScreen extends StatefulWidget {
  final List<Topic> flashcards;
  const GameScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Topic> get _activeCards =>
      widget.flashcards.isNotEmpty ? widget.flashcards : _demoFlashcards;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        title: const Text("Game Mode", style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
        backgroundColor: const Color(0xFF0F0F11),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC5A059),
          labelColor: const Color(0xFFC5A059),
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2),
          tabs: const [
            Tab(icon: Icon(Icons.psychology, size: 20), text: "MATCH"),
            Tab(icon: Icon(Icons.bolt, size: 20), text: "SPEED"),
            Tab(icon: Icon(Icons.keyboard, size: 20), text: "TYPE"),
            Tab(icon: Icon(Icons.favorite, size: 20), text: "SURVIVAL"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Data source indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: const Color(0xFF0F0F11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.flashcards.isNotEmpty ? const Color(0xFF8DA290) : const Color(0xFFC5A059),
                    boxShadow: [BoxShadow(color: (widget.flashcards.isNotEmpty ? const Color(0xFF8DA290) : const Color(0xFFC5A059)).withAlpha(150), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.flashcards.isNotEmpty ? "LIVE DATA • Scores affect revisions" : "DEMO MODE • Scores affect revisions",
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MatchGame(flashcards: _activeCards),
                _SpeedRecallGame(flashcards: _activeCards),
                _TypeChallengeGame(flashcards: _activeCards),
                _SurvivalGame(flashcards: _activeCards),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// GAME 1: MATCH (Card Matching)
// ============================================================
class _MatchGame extends StatefulWidget {
  final List<Topic> flashcards;
  const _MatchGame({Key? key, required this.flashcards}) : super(key: key);

  @override
  _MatchGameState createState() => _MatchGameState();
}

class _MatchGameState extends State<_MatchGame> {
  List<Map<String, dynamic>> _cards = [];
  List<int> _flippedIndices = [];
  Set<String> _matchedIds = {};
  int _moves = 0;
  int _timer = 0;
  Timer? _timerRef;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _timerRef?.cancel();
    super.dispose();
  }

  void _initGame() {
    _timerRef?.cancel();
    final selected = widget.flashcards.take(6).toList();
    List<Map<String, dynamic>> newCards = [];
    for (var fc in selected) {
      newCards.add({'id': fc.id, 'type': 'q', 'text': fc.question});
      newCards.add({'id': fc.id, 'type': 'a', 'text': fc.answer.isEmpty ? 'Hidden...' : fc.answer});
    }
    newCards.shuffle();
    setState(() {
      _cards = newCards;
      _flippedIndices = [];
      _matchedIds = {};
      _moves = 0;
      _timer = 0;
      _isRunning = false;
    });
  }

  void _startTimer() {
    if (!_isRunning) {
      _isRunning = true;
      _timerRef = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _timer++);
      });
    }
  }

  void _handleCardTap(int index) {
    if (_flippedIndices.contains(index) || _matchedIds.contains(_cards[index]['id']) || _flippedIndices.length == 2) return;
    _startTimer();
    setState(() => _flippedIndices.add(index));

    if (_flippedIndices.length == 2) {
      setState(() => _moves++);
      final first = _cards[_flippedIndices[0]];
      final second = _cards[_flippedIndices[1]];

      if (first['id'] == second['id'] && first['type'] != second['type']) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _matchedIds.add(first['id']);
              _flippedIndices.clear();
            });
            final targetCount = widget.flashcards.length > 6 ? 6 : widget.flashcards.length;
            if (_matchedIds.length == targetCount) {
              _timerRef?.cancel();
              _isRunning = false;
              // All matched = remembered
              final results = _matchedIds.map((id) => {'id': id, 'result': 'remembered'}).toList();
              _sendGameResults(results);
            }
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _flippedIndices.clear());
        });
      }
    }
  }

  String _formatTime(int s) => '${(s ~/ 60)}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final targetCount = widget.flashcards.length > 6 ? 6 : widget.flashcards.length;
    final isComplete = _matchedIds.length == targetCount && targetCount > 0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [const Icon(Icons.timer, size: 16, color: Color(0xFFC5A059)), const SizedBox(width: 6), Text(_formatTime(_timer), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white))]),
                Text("$_moves moves", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.grey, size: 20), onPressed: _initGame),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isComplete)
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFFC5A059)),
              const SizedBox(height: 16),
              const Text("Neural Link Established", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
              Text("$_moves moves • ${_formatTime(_timer)}", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              const Text("All cards marked remembered — stability boosted.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _initGame, icon: const Icon(Icons.refresh), label: const Text("PLAY AGAIN", style: TextStyle(fontWeight: FontWeight.bold))),
            ])))
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  final isFlipped = _flippedIndices.contains(index) || _matchedIds.contains(card['id']);
                  final isMatched = _matchedIds.contains(card['id']);
                  return GestureDetector(
                    onTap: () => _handleCardTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: isFlipped ? (isMatched ? const Color(0xFFC5A059).withAlpha(40) : const Color(0xFF1A1A1C)) : const Color(0xFF0F0F11),
                        border: Border.all(color: isFlipped ? (isMatched ? const Color(0xFFC5A059) : const Color(0xFF8DA290).withAlpha(128)) : Colors.white10, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      child: isFlipped
                          ? SingleChildScrollView(child: Text(card['text'], style: TextStyle(color: isMatched ? const Color(0xFFC5A059) : Colors.white, fontSize: 10, fontFamily: 'serif'), textAlign: TextAlign.center))
                          : const Icon(Icons.psychology, size: 28, color: Colors.white12),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


// ============================================================
// GAME 2: SPEED RECALL
// ============================================================
class _SpeedRecallGame extends StatefulWidget {
  final List<Topic> flashcards;
  const _SpeedRecallGame({Key? key, required this.flashcards}) : super(key: key);

  @override
  _SpeedRecallGameState createState() => _SpeedRecallGameState();
}

class _SpeedRecallGameState extends State<_SpeedRecallGame> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _remembered = 0;
  int _forgot = 0;
  int _timer = 0;
  Timer? _timerRef;
  bool _isRunning = false;
  bool _isComplete = false;
  int _streak = 0;
  int _maxStreak = 0;
  List<Map<String, String>> _results = [];

  @override
  void dispose() { _timerRef?.cancel(); super.dispose(); }

  void _startGame() {
    _timerRef?.cancel();
    setState(() { _currentIndex = 0; _showAnswer = false; _remembered = 0; _forgot = 0; _timer = 0; _isRunning = true; _isComplete = false; _streak = 0; _maxStreak = 0; _results = []; });
    _timerRef = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _timer++); });
  }

  void _handleResult(String result) {
    final current = widget.flashcards[_currentIndex];
    _results.add({'id': current.id, 'result': result});
    if (result == 'remembered') { _remembered++; _streak++; if (_streak > _maxStreak) _maxStreak = _streak; }
    else { _forgot++; _streak = 0; }

    if (_currentIndex + 1 >= widget.flashcards.length) {
      _timerRef?.cancel();
      setState(() { _isComplete = true; _isRunning = false; });
      _sendGameResults(_results);
    } else {
      setState(() { _currentIndex++; _showAnswer = false; });
    }
  }

  String _formatTime(int s) => '${(s ~/ 60)}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_isRunning && !_isComplete) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFC5A059).withAlpha(30), border: Border.all(color: const Color(0xFFC5A059).withAlpha(80))), child: const Icon(Icons.bolt, size: 36, color: Color(0xFFC5A059))),
        const SizedBox(height: 20),
        const Text("Speed Recall", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
        const SizedBox(height: 8),
        const Text("Rate your recall honestly. Failed cards trigger revision.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _startGame, icon: const Icon(Icons.bolt), label: const Text("BEGIN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5))),
      ])));
    }

    if (_isComplete) {
      final accuracy = (_remembered + _forgot) > 0 ? ((_remembered / (_remembered + _forgot)) * 100).round() : 0;
      return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.emoji_events, size: 60, color: Color(0xFFC5A059)),
        const SizedBox(height: 16),
        const Text("Complete!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
        Text(_forgot > 0 ? "$_forgot card(s) flagged for revision." : "Perfect! Stability boosted.", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _StatChip("$accuracy%", "Accuracy"),
          _StatChip("$_maxStreak", "Streak"),
          _StatChip(_formatTime(_timer), "Time"),
        ]),
        const SizedBox(height: 24),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _startGame, icon: const Icon(Icons.refresh), label: const Text("AGAIN")),
      ])));
    }

    final current = widget.flashcards[_currentIndex];
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      // Top bar
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_formatTime(_timer), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white)),
          if (_streak > 1) Row(children: [const Icon(Icons.local_fire_department, size: 14, color: Colors.orange), Text(" $_streak", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))]),
          Text("${_currentIndex + 1}/${widget.flashcards.length}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: _currentIndex / widget.flashcards.length, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Color(0xFFC5A059)), minHeight: 4),
      const SizedBox(height: 20),
      Expanded(child: Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(current.topicName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFC5A059))),
          const SizedBox(height: 16),
          Text(current.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: Colors.white, height: 1.4)),
          const SizedBox(height: 24),
          if (_showAnswer) ...[
            Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF8DA290).withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8DA290).withAlpha(80))),
              child: Text(current.answer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontFamily: 'serif', fontStyle: FontStyle.italic, color: Color(0xFF8DA290)))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8DA290), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleResult('remembered'), child: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleResult('forgot'), child: const Text("FORGOT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
            ]),
          ] else
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: () => setState(() => _showAnswer = true), child: const Text("REVEAL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))),
        ]),
      )),
    ]));
  }
}


// ============================================================
// GAME 3: TYPE CHALLENGE
// ============================================================
class _TypeChallengeGame extends StatefulWidget {
  final List<Topic> flashcards;
  const _TypeChallengeGame({Key? key, required this.flashcards}) : super(key: key);

  @override
  _TypeChallengeGameState createState() => _TypeChallengeGameState();
}

class _TypeChallengeGameState extends State<_TypeChallengeGame> {
  int _currentIndex = 0;
  final TextEditingController _inputCtrl = TextEditingController();
  bool _isRunning = false;
  bool _isComplete = false;
  int _timer = 0;
  Timer? _timerRef;
  List<Map<String, dynamic>> _scores = [];
  List<Map<String, String>> _results = [];
  Map<String, dynamic>? _feedback;

  @override
  void dispose() { _timerRef?.cancel(); _inputCtrl.dispose(); super.dispose(); }

  void _startGame() {
    _timerRef?.cancel();
    _inputCtrl.clear();
    setState(() { _currentIndex = 0; _isRunning = true; _isComplete = false; _timer = 0; _scores = []; _results = []; _feedback = null; });
    _timerRef = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _timer++); });
  }

  int _calcSimilarity(String input, String answer) {
    final aWords = input.toLowerCase().trim().split(RegExp(r'\s+')).toSet();
    final bWords = answer.toLowerCase().trim().split(RegExp(r'\s+')).toSet();
    if (aWords.isEmpty || bWords.isEmpty) return 0;
    int matches = aWords.intersection(bWords).length;
    return ((matches / bWords.length) * 100).round();
  }

  void _submit() {
    final current = widget.flashcards[_currentIndex];
    final similarity = _calcSimilarity(_inputCtrl.text, current.answer);
    final passed = similarity >= 40;
    final result = passed ? 'remembered' : 'forgot';
    _scores.add({'similarity': similarity, 'passed': passed});
    _results.add({'id': current.id, 'result': result});
    setState(() => _feedback = {'similarity': similarity, 'passed': passed, 'answer': current.answer});

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      if (_currentIndex + 1 >= widget.flashcards.length) {
        _timerRef?.cancel();
        setState(() { _isComplete = true; _isRunning = false; });
        _sendGameResults(_results);
      } else {
        _inputCtrl.clear();
        setState(() { _currentIndex++; _feedback = null; });
      }
    });
  }

  void _skip() {
    final current = widget.flashcards[_currentIndex];
    _scores.add({'similarity': 0, 'passed': false});
    _results.add({'id': current.id, 'result': 'forgot'});
    if (_currentIndex + 1 >= widget.flashcards.length) {
      _timerRef?.cancel();
      setState(() { _isComplete = true; _isRunning = false; });
      _sendGameResults(_results);
    } else {
      _inputCtrl.clear();
      setState(() { _currentIndex++; _feedback = null; });
    }
  }

  String _formatTime(int s) => '${(s ~/ 60)}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_isRunning && !_isComplete) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFC5A059).withAlpha(30), border: Border.all(color: const Color(0xFFC5A059).withAlpha(80))), child: const Icon(Icons.keyboard, size: 36, color: Color(0xFFC5A059))),
        const SizedBox(height: 20),
        const Text("Type Challenge", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
        const SizedBox(height: 8),
        const Text("Type your answer from memory. 40%+ keyword match = pass.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _startGame, icon: const Icon(Icons.keyboard), label: const Text("START", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5))),
      ])));
    }

    if (_isComplete) {
      final passed = _scores.where((s) => s['passed'] == true).length;
      final avgSim = _scores.isNotEmpty ? (_scores.map((s) => s['similarity'] as int).reduce((a, b) => a + b) / _scores.length).round() : 0;
      return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.workspace_premium, size: 60, color: Color(0xFFC5A059)),
        const SizedBox(height: 16),
        const Text("Challenge Done!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
        Text("${_scores.length - passed} failed — revision triggered.", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _StatChip("$passed/${widget.flashcards.length}", "Passed"),
          _StatChip("$avgSim%", "Avg Match"),
          _StatChip(_formatTime(_timer), "Time"),
        ]),
        const SizedBox(height: 24),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _startGame, icon: const Icon(Icons.refresh), label: const Text("AGAIN")),
      ])));
    }

    final current = widget.flashcards[_currentIndex];
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_formatTime(_timer), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white)),
          Text("${_currentIndex + 1}/${widget.flashcards.length}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: _currentIndex / widget.flashcards.length, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Color(0xFFC5A059)), minHeight: 4),
      const SizedBox(height: 16),
      Text(current.topicName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFC5A059))),
      const SizedBox(height: 12),
      Text(current.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontFamily: 'serif', color: Colors.white)),
      const SizedBox(height: 20),
      if (_feedback != null)
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: (_feedback!['passed'] as bool) ? const Color(0xFF8DA290).withAlpha(25) : Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(14), border: Border.all(color: (_feedback!['passed'] as bool) ? const Color(0xFF8DA290) : Colors.red)),
          child: Column(children: [
            Text("${_feedback!['similarity']}% Match", style: TextStyle(fontWeight: FontWeight.bold, color: (_feedback!['passed'] as bool) ? const Color(0xFF8DA290) : Colors.red)),
            const SizedBox(height: 6),
            Text(_feedback!['answer'], style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
          ]))
      else ...[
        Expanded(child: TextField(controller: _inputCtrl, maxLines: 4, decoration: InputDecoration(hintText: "Type from memory...", hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF0F0F11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: _inputCtrl.text.trim().isNotEmpty ? _submit : null, child: const Text("SUBMIT", style: TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: _skip, child: const Text("SKIP")),
        ]),
      ],
    ]));
  }
}


// ============================================================
// GAME 4: SURVIVAL MODE (3 lives, endless)
// ============================================================
class _SurvivalGame extends StatefulWidget {
  final List<Topic> flashcards;
  const _SurvivalGame({Key? key, required this.flashcards}) : super(key: key);

  @override
  _SurvivalGameState createState() => _SurvivalGameState();
}

class _SurvivalGameState extends State<_SurvivalGame> {
  List<Topic> _shuffled = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _lives = 3;
  int _score = 0;
  bool _isRunning = false;
  bool _isComplete = false;
  int _timer = 0;
  Timer? _timerRef;
  int _streak = 0;
  int _highScore = 0;
  List<Map<String, String>> _results = [];

  @override
  void dispose() { _timerRef?.cancel(); super.dispose(); }

  void _startGame() {
    _timerRef?.cancel();
    final doubled = [...widget.flashcards, ...widget.flashcards, ...widget.flashcards]..shuffle();
    setState(() { _shuffled = doubled; _currentIndex = 0; _showAnswer = false; _lives = 3; _score = 0; _isRunning = true; _isComplete = false; _timer = 0; _streak = 0; _results = []; });
    _timerRef = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _timer++); });
  }

  void _handleResult(String result) {
    final current = _shuffled[_currentIndex];
    _results.add({'id': current.id, 'result': result});

    if (result == 'remembered') {
      _score += 1 + (_streak ~/ 3);
      _streak++;
    } else {
      _lives--;
      _streak = 0;
      if (_lives <= 0) {
        _timerRef?.cancel();
        if (_score > _highScore) _highScore = _score;
        setState(() { _isComplete = true; _isRunning = false; });
        _sendGameResults(_results);
        return;
      }
    }

    if (_currentIndex + 1 >= _shuffled.length) {
      final doubled = [...widget.flashcards, ...widget.flashcards, ...widget.flashcards]..shuffle();
      setState(() { _shuffled = doubled; _currentIndex = 0; _showAnswer = false; });
    } else {
      setState(() { _currentIndex++; _showAnswer = false; });
    }
  }

  String _formatTime(int s) => '${(s ~/ 60)}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_isRunning && !_isComplete) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withAlpha(30), border: Border.all(color: Colors.red.withAlpha(80))), child: const Icon(Icons.favorite, size: 36, color: Colors.redAccent)),
        const SizedBox(height: 20),
        const Text("Survival Mode", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
        const SizedBox(height: 8),
        const Text("3 lives. Each 'forgot' costs one. Failed cards get flagged.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (_) => const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.favorite, color: Colors.redAccent, size: 28)))),
        if (_highScore > 0) ...[const SizedBox(height: 12), Text("High Score: $_highScore", style: const TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold))],
        const SizedBox(height: 30),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _startGame, icon: const Icon(Icons.favorite), label: const Text("ENTER ARENA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5))),
      ])));
    }

    if (_isComplete) {
      final forgot = _results.where((r) => r['result'] == 'forgot').length;
      return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.heart_broken, size: 60, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text("Game Over", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
        Text("$forgot card(s) flagged for revision.", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _StatChip("$_score", "Score"),
          _StatChip("${_results.where((r) => r['result'] == 'remembered').length}", "Recalled"),
          _StatChip(_formatTime(_timer), "Survived"),
        ]),
        const SizedBox(height: 24),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: _startGame, icon: const Icon(Icons.refresh), label: const Text("TRY AGAIN")),
      ])));
    }

    if (_currentIndex >= _shuffled.length) return const SizedBox();
    final current = _shuffled[_currentIndex];

    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: List.generate(3, (i) => Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.favorite, size: 18, color: i < _lives ? Colors.redAccent : Colors.white10)))),
          Row(children: [const Icon(Icons.star, size: 16, color: Color(0xFFC5A059)), const SizedBox(width: 4), Text("$_score", style: const TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold))]),
          if (_streak > 2) Row(children: [const Icon(Icons.local_fire_department, size: 14, color: Colors.orange), Text(" x${1 + _streak ~/ 3}", style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))]),
          Text(_formatTime(_timer), style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 20),
      Expanded(child: Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(current.topicName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFC5A059))),
          const SizedBox(height: 16),
          Text(current.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: Colors.white, height: 1.4)),
          const SizedBox(height: 24),
          if (_showAnswer) ...[
            Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF8DA290).withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8DA290).withAlpha(80))),
              child: Text(current.answer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontFamily: 'serif', fontStyle: FontStyle.italic, color: Color(0xFF8DA290)))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8DA290), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleResult('remembered'), child: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleResult('forgot'), child: const Text("-1 LIFE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
            ]),
          ] else
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), onPressed: () => setState(() => _showAnswer = true), child: const Text("REVEAL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))),
        ]),
      )),
    ]));
  }
}

// ============================================================
// HELPER WIDGET
// ============================================================
class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF0F0F11), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC5A059), fontFamily: 'monospace')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
      ]),
    );
  }
}
