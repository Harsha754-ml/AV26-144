import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';

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
// MAIN GAME SCREEN - Tab between Match & Speed Recall
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
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text("Cognitive Arena", style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
        backgroundColor: const Color(0xFF0F0F11),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC5A059),
          labelColor: const Color(0xFFC5A059),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: "MATCH"),
            Tab(icon: Icon(Icons.bolt), text: "SPEED RECALL"),
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
                    boxShadow: [BoxShadow(color: widget.flashcards.isNotEmpty ? const Color(0xFF8DA290) : const Color(0xFFC5A059), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.flashcards.isNotEmpty ? "LIVE DATA ACTIVE" : "DEMO MODE",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GAME 1: SYNAPTIC MATCH (Memory Card Matching)
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
  int? _bestScore;

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

  @override
  void didUpdateWidget(_MatchGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flashcards != oldWidget.flashcards) {
      _initGame();
    }
  }

  void _initGame() {
    _timerRef?.cancel();
    final selected = widget.flashcards.take(6).toList();
    List<Map<String, dynamic>> newCards = [];
    for (var fc in selected) {
      newCards.add({'id': fc.id, 'type': 'q', 'text': fc.question});
      newCards.add({'id': fc.id, 'type': 'a', 'text': fc.answer.isEmpty ? 'Hidden Answer...' : fc.answer});
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
            // Check completion
            final targetCount = widget.flashcards.length > 6 ? 6 : widget.flashcards.length;
            if (_matchedIds.length == targetCount) {
              _timerRef?.cancel();
              _isRunning = false;
              if (_bestScore == null || _moves < _bestScore!) {
                _bestScore = _moves;
              }
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

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final targetCount = widget.flashcards.length > 6 ? 6 : widget.flashcards.length;
    final isComplete = _matchedIds.length == targetCount;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F11),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.timer, size: 18, color: Color(0xFFC5A059)),
                  const SizedBox(width: 8),
                  Text(_formatTime(_timer), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white)),
                ]),
                Row(children: [
                  const Icon(Icons.touch_app, size: 18, color: Color(0xFF8DA290)),
                  const SizedBox(width: 8),
                  Text("$_moves moves", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                if (_bestScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.3)),
                    ),
                    child: Text("Best: $_bestScore", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                  ),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.grey), onPressed: _initGame, iconSize: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isComplete)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFC5A059).withOpacity(0.2),
                        border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.5), width: 2),
                      ),
                      child: const Icon(Icons.check_circle_outline, size: 60, color: Color(0xFFC5A059)),
                    ),
                    const SizedBox(height: 20),
                    const Text("Neural Link Established", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
                    const SizedBox(height: 8),
                    Text("$_moves moves • ${_formatTime(_timer)}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      onPressed: _initGame,
                      icon: const Icon(Icons.refresh),
                      label: const Text("PLAY AGAIN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.7,
                ),
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
                        color: isFlipped
                            ? (isMatched ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFF1A1A1C))
                            : const Color(0xFF0F0F11),
                        border: Border.all(
                          color: isFlipped
                              ? (isMatched ? const Color(0xFFC5A059) : const Color(0xFF8DA290).withOpacity(0.5))
                              : Colors.white10,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isMatched ? [BoxShadow(color: const Color(0xFFC5A059).withOpacity(0.3), blurRadius: 12, spreadRadius: -4)] : [],
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(10),
                      child: isFlipped
                          ? SingleChildScrollView(
                              child: Text(
                                card['text'],
                                style: TextStyle(
                                  color: isMatched ? const Color(0xFFC5A059) : Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'serif',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : const Icon(Icons.psychology, size: 32, color: Colors.white12),
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
// GAME 2: SPEED RECALL (Timed Quiz)
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

  @override
  void dispose() {
    _timerRef?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timerRef?.cancel();
    setState(() {
      _currentIndex = 0;
      _showAnswer = false;
      _remembered = 0;
      _forgot = 0;
      _timer = 0;
      _isRunning = true;
      _isComplete = false;
      _streak = 0;
      _maxStreak = 0;
    });
    _timerRef = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _timer++);
    });
  }

  void _handleResult(String result) {
    if (result == 'remembered') {
      _remembered++;
      _streak++;
      if (_streak > _maxStreak) _maxStreak = _streak;
    } else {
      _forgot++;
      _streak = 0;
    }

    if (_currentIndex + 1 >= widget.flashcards.length) {
      _timerRef?.cancel();
      setState(() {
        _isComplete = true;
        _isRunning = false;
      });
    } else {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    }
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Start screen
    if (!_isRunning && !_isComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A059).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.3)),
                ),
                child: const Icon(Icons.bolt, size: 40, color: Color(0xFFC5A059)),
              ),
              const SizedBox(height: 24),
              const Text("Speed Recall", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
              const SizedBox(height: 8),
              const Text("Test your memory under pressure.", style: TextStyle(color: Color(0xFF8DA290), fontStyle: FontStyle.italic, fontSize: 16)),
              const SizedBox(height: 16),
              Text("${widget.flashcards.length} cards • Timed", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _startGame,
                icon: const Icon(Icons.bolt),
                label: const Text("BEGIN PROTOCOL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      );
    }

    // Complete screen
    if (_isComplete) {
      final accuracy = (_remembered + _forgot) > 0 ? ((_remembered / (_remembered + _forgot)) * 100).round() : 0;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A059).withOpacity(0.2),
                  border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.emoji_events, size: 50, color: Color(0xFFC5A059)),
              ),
              const SizedBox(height: 20),
              const Text("Protocol Complete", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
              const SizedBox(height: 8),
              Text("Finished in ${_formatTime(_timer)}", style: const TextStyle(color: Color(0xFF8DA290), fontStyle: FontStyle.italic, fontSize: 16)),
              const SizedBox(height: 30),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBox(label: "Accuracy", value: "$accuracy%", color: const Color(0xFF8DA290)),
                  _StatBox(label: "Streak", value: "$_maxStreak", color: const Color(0xFFC5A059)),
                  _StatBox(label: "Time", value: _formatTime(_timer), color: Colors.white),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF8DA290))),
                  const SizedBox(width: 6),
                  Text("Remembered: $_remembered", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 20),
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.shade400)),
                  const SizedBox(width: 6),
                  Text("Forgot: $_forgot", style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: _startGame,
                icon: const Icon(Icons.refresh),
                label: const Text("TRY AGAIN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      );
    }

    // Active game
    final current = widget.flashcards[_currentIndex];
    final progress = (_currentIndex) / widget.flashcards.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F11),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.timer, size: 16, color: Color(0xFFC5A059)),
                  const SizedBox(width: 6),
                  Text(_formatTime(_timer), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white)),
                ]),
                if (_streak > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text("$_streak", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ]),
                  ),
                Text("${_currentIndex + 1}/${widget.flashcards.length}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC5A059)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 24),

          // Card
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F11),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(current.topicName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFC5A059))),
                  const SizedBox(height: 20),
                  Text(current.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontFamily: 'serif', color: Colors.white, height: 1.4)),
                  const SizedBox(height: 30),

                  if (_showAnswer) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8DA290).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF8DA290).withOpacity(0.3)),
                      ),
                      child: Text(current.answer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontFamily: 'serif', fontStyle: FontStyle.italic, color: Color(0xFF8DA290), height: 1.4)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8DA290), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            onPressed: () => _handleResult('remembered'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            onPressed: () => _handleResult('forgot'),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("FORGOT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () => setState(() => _showAnswer = true),
                      child: const Text("REVEAL ANSWER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for stats display
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        ],
      ),
    );
  }
}
