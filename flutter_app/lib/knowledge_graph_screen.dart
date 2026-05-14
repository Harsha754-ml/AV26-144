import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

/// Knowledge Graph Screen - Visualizes topic connections
class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({Key? key}) : super(key: key);

  @override
  _KnowledgeGraphScreenState createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> with SingleTickerProviderStateMixin {
  List<_GraphNode> _nodes = [];
  List<_GraphEdge> _edges = [];
  bool _loading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fetchGraph();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchGraph() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.backendUrl}/knowledge-graph'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nodes = (data['nodes'] as List).map((n) => _GraphNode(
          id: n['id'],
          name: n['name'] ?? n['id'],
          retention: n['retention'] ?? 50,
          cards: n['cards'] ?? 1,
          color: _parseColor(n['color'] ?? '#c5a059'),
        )).toList();
        final edges = (data['links'] as List).map((e) => _GraphEdge(
          source: e['source'],
          target: e['target'],
        )).toList();

        // Assign positions in a circle layout
        _layoutNodes(nodes);

        setState(() {
          _nodes = nodes;
          _edges = edges;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _layoutNodes(List<_GraphNode> nodes) {
    final center = const Offset(0.5, 0.5);
    final radius = 0.35;
    for (int i = 0; i < nodes.length; i++) {
      final angle = (2 * pi * i) / nodes.length - pi / 2;
      nodes[i].x = center.dx + radius * cos(angle);
      nodes[i].y = center.dy + radius * sin(angle);
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        title: const Text("Neural Graph", style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
        backgroundColor: const Color(0xFF0F0F11),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)))
          : _nodes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hub, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No Knowledge Graph Yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
                      SizedBox(height: 8),
                      Text("Upload content to build your neural network.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Legend
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFF0F0F11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: const Color(0xFFC5A059), label: "Strong (70%+)"),
                          const SizedBox(width: 16),
                          _LegendDot(color: const Color(0xFFF59E0B), label: "Decaying"),
                          const SizedBox(width: 16),
                          _LegendDot(color: const Color(0xFFF43F5E), label: "Critical"),
                        ],
                      ),
                    ),
                    // Graph
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _GraphPainter(nodes: _nodes, edges: _edges, pulse: _animController.value),
                            size: Size.infinite,
                          );
                        },
                      ),
                    ),
                    // Node list
                    Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _nodes.length,
                        itemBuilder: (context, index) {
                          final node = _nodes[index];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0F11),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: node.color.withAlpha(80)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(node.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text("${node.retention}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: node.color)),
                                    const Spacer(),
                                    Text("${node.cards} cards", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: node.retention / 100,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation(node.color),
                                    minHeight: 3,
                                  ),
                                ),
                              ],
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

// Graph Painter
class _GraphPainter extends CustomPainter {
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final double pulse;

  _GraphPainter({required this.nodes, required this.edges, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    final edgePaint = Paint()
      ..color = const Color(0xFFC5A059).withAlpha(40)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final source = nodes.firstWhere((n) => n.id == edge.source, orElse: () => nodes.first);
      final target = nodes.firstWhere((n) => n.id == edge.target, orElse: () => nodes.last);
      canvas.drawLine(
        Offset(source.x * size.width, source.y * size.height),
        Offset(target.x * size.width, target.y * size.height),
        edgePaint,
      );
    }

    // Draw nodes
    for (final node in nodes) {
      final center = Offset(node.x * size.width, node.y * size.height);
      final radius = 12.0 + node.cards * 3.0;

      // Glow
      final glowPaint = Paint()
        ..color = node.color.withAlpha((30 + (pulse * 20)).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius + 6, glowPaint);

      // Node circle
      final nodePaint = Paint()..color = node.color;
      canvas.drawCircle(center, radius, nodePaint);

      // Border
      final borderPaint = Paint()
        ..color = node.color.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, borderPaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: "${node.retention}%",
          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

      // Name below
      final namePainter = TextPainter(
        text: TextSpan(
          text: node.name.length > 12 ? '${node.name.substring(0, 12)}...' : node.name,
          style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      namePainter.paint(canvas, Offset(center.dx - namePainter.width / 2, center.dy + radius + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Data models
class _GraphNode {
  final String id;
  final String name;
  final int retention;
  final int cards;
  final Color color;
  double x;
  double y;

  _GraphNode({required this.id, required this.name, required this.retention, required this.cards, required this.color, this.x = 0.5, this.y = 0.5});
}

class _GraphEdge {
  final String source;
  final String target;
  _GraphEdge({required this.source, required this.target});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
