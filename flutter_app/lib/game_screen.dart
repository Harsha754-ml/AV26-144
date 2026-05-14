import 'package:flutter/material.dart';
import 'models.dart';

class GameScreen extends StatefulWidget {
  final List<Topic> flashcards;
  const GameScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Map<String, dynamic>> _cards = [];
  List<int> _flippedIndices = [];
  Set<String> _matchedIds = {};
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flashcards != oldWidget.flashcards) {
      _initGame();
    }
  }

  void _initGame() {
    if (widget.flashcards.isEmpty) {
      setState(() => _cards = []);
      return;
    }

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
    });
  }

  void _handleCardTap(int index) {
    if (_flippedIndices.contains(index) || _matchedIds.contains(_cards[index]['id']) || _flippedIndices.length == 2) {
      return;
    }

    setState(() {
      _flippedIndices.add(index);
    });

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
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _flippedIndices.clear();
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.gamepad, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No Neural Data", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Upload a resource first.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final isComplete = _matchedIds.length == (widget.flashcards.length > 6 ? 6 : widget.flashcards.length);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Synaptic Match", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFC5A059), fontFamily: 'serif')),
                Text("Moves: $_moves", style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text("Reinforce neural pathways by matching concepts to definitions.", style: TextStyle(color: Color(0xFF8DA290), fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            
            if (isComplete)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFFC5A059)),
                      const SizedBox(height: 16),
                      const Text("Neural Link Established", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("Completed in $_moves moves.", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                        onPressed: _initGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text("RECALIBRATE MATRIX", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
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
                              ? (isMatched ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF1A1A1C))
                              : const Color(0xFF0F0F11),
                          border: Border.all(
                            color: isFlipped
                                ? (isMatched ? const Color(0xFFC5A059) : const Color(0xFF8DA290).withOpacity(0.5))
                                : Colors.white10,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isMatched ? [const BoxShadow(color: Color(0xFFC5A059), blurRadius: 10, spreadRadius: -5)] : [],
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(12),
                        child: isFlipped
                            ? SingleChildScrollView(
                                child: Text(
                                  card['text'],
                                  style: TextStyle(
                                    color: isMatched ? const Color(0xFFC5A059) : Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'serif',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : const Icon(Icons.psychology, size: 40, color: Colors.white12),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
