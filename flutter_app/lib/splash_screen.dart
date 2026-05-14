import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  double _progress = 0;
  int _phase = 0;
  String _statusText = 'Initializing HLR Engine...';

  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    
    _logoController.forward();
    
    // Phase transitions
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() => _phase = 1); });
    Future.delayed(const Duration(milliseconds: 1200), () { if (mounted) setState(() => _phase = 2); _startProgress(); });
  }

  void _startProgress() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _progress += (100 - _progress) * 0.08 + 2;
        if (_progress > 30 && _progress < 60) _statusText = 'Loading Neural Graph...';
        if (_progress > 60 && _progress < 85) _statusText = 'Calibrating Retention Model...';
        if (_progress >= 85) _statusText = 'System Ready';
        if (_progress >= 100) {
          _progress = 100;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) widget.onComplete();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: const Color(0xFFC5A059).withAlpha(100), blurRadius: 40, spreadRadius: -10)],
                    ),
                    child: const Icon(Icons.psychology, size: 44, color: Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Title
            AnimatedOpacity(
              opacity: _phase >= 1 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  const Text("MemoryForge", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFFC5A059), fontFamily: 'serif', letterSpacing: -1)),
                  const SizedBox(height: 6),
                  Text("COGNITIVE OPERATING SYSTEM V2", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 4, color: const Color(0xFF8DA290).withAlpha(200))),
                ],
              ),
            ),
            const SizedBox(height: 50),

            // Progress bar
            AnimatedOpacity(
              opacity: _phase >= 2 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress / 100,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFC5A059)),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_statusText, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                        Text("${_progress.round()}%", style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFC5A059), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Tech badges
            AnimatedOpacity(
              opacity: _phase >= 2 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Wrap(
                spacing: 8,
                children: ['PyTorch', 'Gemini AI', 'CrewAI'].map((tech) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                  child: Text(tech, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
