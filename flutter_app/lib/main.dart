import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'models.dart';
import 'constants.dart';
import 'game_screen.dart';
import 'knowledge_graph_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    debugPrint("Notification init failed: $e");
  }
  runApp(const MemoryForgeApp());
}

class MemoryForgeApp extends StatelessWidget {
  const MemoryForgeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MemoryForge',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFC5A059), // Gold accent
        scaffoldBackgroundColor: const Color(0xFF0A0A0B), // Dashboard bg
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F11),
          elevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFFF4F1EA), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif'),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF4F1EA)),
          bodyMedium: TextStyle(color: Color(0xFFF4F1EA)),
        ),
        cardColor: const Color(0xFF0F0F11),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFC5A059),
          foregroundColor: Colors.black,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F11),
          selectedItemColor: Color(0xFFC5A059),
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Topic> _flashcards = [];
  Set<String> _shownNotifications = {};
  Timer? _pollingTimer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Start background sync for offline game results
    startGameSyncService();
    // Start background polling for local isolated network
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollNotifications();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final cards = await ApiService.getFlashcards();
      setState(() {
        _flashcards = cards;
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      debugPrint("Failed to fetch flashcards: $e");
    }
  }

  Future<void> _pollNotifications() async {
    try {
      final notifications = await ApiService.getPendingNotifications();
      setState(() { _isConnected = true; });
      if (notifications.isNotEmpty) {
        for (var n in notifications) {
          if (!_shownNotifications.contains(n.notificationId)) {
            _shownNotifications.add(n.notificationId);
            _showPushNotification(n);
            _showBanner(n);
          }
        }
      }
    } catch (e) {
      setState(() { _isConnected = false; });
    }
  }

  Future<void> _showPushNotification(NotificationDetail notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'memory_forge_channel',
      'Memory Alerts',
      channelDescription: 'Notifications for memory decay',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    try {
      await flutterLocalNotificationsPlugin.show(
        notification.notificationId.hashCode,
        'Memory Decay: ${notification.topicName}',
        'Retention dropped to ${notification.retentionScore}%! Review now.',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint("Notification show failed: $e");
    }
  }

  void _showBanner(NotificationDetail notification) {
    // Clear notification locally
    ApiService.clearNotification(notification.notificationId);
    
    // Clear previous banners so they don't stack infinitely
    ScaffoldMessenger.of(context).clearMaterialBanners();

    // Calculate Banner Color
    Color urgencyColor = const Color(0xFF8DA290); // default greenish
    if (notification.urgencyLevel == "critical") urgencyColor = Colors.redAccent;
    if (notification.urgencyLevel == "warning" || notification.urgencyLevel == "danger") urgencyColor = Colors.orangeAccent;

    final bannerController = ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          "Review Time: ${notification.topicName} (Retention: ${notification.retentionScore}%)",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.warning_rounded, color: Colors.white),
        backgroundColor: urgencyColor,
        actions: [
          TextButton(
            onPressed: () {
              final player = AudioPlayer();
              player.play(UrlSource(notification.audioUrl));
            },
            child: const Text('PLAY AUDIO', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              // Navigate based on action
              if (notification.action == 'force_quiz' || notification.action == 'open_quiz') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(flashcardId: notification.flashcardId, question: notification.question)));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(notification: notification)));
              }
            },
            child: Text(
              (notification.action == 'force_quiz' || notification.action == 'open_quiz') ? 'TAKE QUIZ' : 'REVIEW NOW', 
              style: const TextStyle(color: Colors.white)
            ),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('DISMISS', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
    
    // Auto-close banner after 10s
    Future.delayed(const Duration(seconds: 10), () {
       if (mounted) {
         ScaffoldMessenger.of(context).clearMaterialBanners();
       }
    });
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F11),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return const AddBottomSheet();
      },
    ).then((_) => _fetchData());
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(flashcards: _flashcards, isConnected: _isConnected, onRefresh: _fetchData),
      GameScreen(flashcards: _flashcards),
      const KnowledgeGraphScreen(),
      AudioReviewScreen(flashcards: _flashcards),
      SettingsScreen()
    ];

    return Scaffold(
      body: screens[_currentIndex],
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: FloatingActionButton(
          onPressed: _showAddDialog,
          backgroundColor: const Color(0xFFC5A059),
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F0F11),
        selectedItemColor: const Color(0xFFC5A059),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: 'Games'),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: 'Graph'),
          BottomNavigationBarItem(icon: Icon(Icons.headphones), label: 'Audio'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// HOME SCREEN - Rich Dashboard with Demo Data
// ----------------------------------------------------

// ----------------------------------------------------
// HOME SCREEN - Rich Dashboard
// ----------------------------------------------------
class HomeScreen extends StatelessWidget {
  final List<Topic> flashcards;
  final bool isConnected;
  final VoidCallback onRefresh;

  const HomeScreen({Key? key, required this.flashcards, required this.isConnected, required this.onRefresh}) : super(key: key);

  List<Topic> get _activeCards => flashcards;
  bool get _isDemo => false;

  @override
  Widget build(BuildContext context) {
    final cards = _activeCards;
    final criticalCount = cards.where((c) => c.urgencyLevel == 'critical').length;
    final warningCount = cards.where((c) => c.urgencyLevel == 'warning' || c.urgencyLevel == 'danger').length;
    final avgRetention = cards.isNotEmpty ? (cards.map((c) => c.retentionScore).reduce((a, b) => a + b) / cards.length).round() : 0;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFFC5A059),
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F11),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology, size: 16, color: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  const Text("MemoryForge", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif', fontSize: 18, color: Color(0xFFC5A059))),
                  const SizedBox(width: 8),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? const Color(0xFF8DA290) : Colors.redAccent,
                      boxShadow: [BoxShadow(color: (isConnected ? const Color(0xFF8DA290) : Colors.redAccent).withAlpha(128), blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Demo Mode Banner
          if (_isDemo)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5A059).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC5A059).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFC5A059), boxShadow: [BoxShadow(color: const Color(0xFFC5A059).withAlpha(128), blurRadius: 4)])),
                    const SizedBox(width: 10),
                    const Text("SIMULATION MODE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFC5A059))),
                    const Spacer(),
                    const Text("Demo data active", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Status Cards Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _StatusCard(label: "NODES", value: "${cards.length}", icon: Icons.layers, color: const Color(0xFFC5A059))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatusCard(label: "CRITICAL", value: "$criticalCount", icon: Icons.warning_amber, color: Colors.redAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatusCard(label: "RETENTION", value: "$avgRetention%", icon: Icons.shield, color: const Color(0xFF8DA290))),
                ],
              ),
            ),
          ),

          // Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFC5A059), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Text("KNOWLEDGE CLUSTERS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
                  const Spacer(),
                  Text("${cards.length} active", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),

          // Flashcard List - Rich Cards
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final fc = cards[index];
                return _FlashcardTile(topic: fc);
              },
              childCount: cards.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// Rich Status Card Widget
class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatusCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
        ],
      ),
    );
  }
}

// Rich Flashcard Tile
class _FlashcardTile extends StatelessWidget {
  final Topic topic;
  const _FlashcardTile({required this.topic});

  Color get _urgencyColor {
    switch (topic.urgencyLevel) {
      case 'critical': return Colors.redAccent;
      case 'danger': return Colors.orange;
      case 'warning': return Colors.amber;
      default: return const Color(0xFF8DA290);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: topic.urgencyLevel == 'critical' ? Colors.redAccent.withAlpha(60) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: topic name + urgency badge
          Row(
            children: [
              Expanded(
                child: Text(topic.topicName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF4F1EA), fontFamily: 'serif')),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _urgencyColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _urgencyColor.withAlpha(80)),
                ),
                child: Text(topic.urgencyLevel.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: _urgencyColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question preview
          Text(
            '"${topic.question}"',
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic, fontFamily: 'serif', height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Audio buttons
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final player = AudioPlayer();
                  // Try backend audio, uses gTTS-generated MP3
                  player.play(UrlSource('${AppConstants.backendUrl}/audio/${topic.id}'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC5A059).withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.volume_up, size: 14, color: Color(0xFFC5A059)),
                      SizedBox(width: 6),
                      Text("LISTEN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFFC5A059))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final player = AudioPlayer();
                  // Read question aloud via backend TTS
                  player.play(UrlSource('${AppConstants.backendUrl}/audio/${topic.id}'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.record_voice_over, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Text("READ", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom row: retention score + next reminder
          Row(
            children: [
              // Retention score bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("${topic.retentionScore}%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _urgencyColor)),
                        const SizedBox(width: 8),
                        const Text("retention", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: topic.retentionScore / 100,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(_urgencyColor),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Next reminder
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFC5A059)),
                    const SizedBox(width: 6),
                    Text("${topic.nextReminderMinutes}m", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// ADD BOTTOM SHEET (Multi Modal Ingestion)
// ----------------------------------------------------
class AddBottomSheet extends StatefulWidget {
  const AddBottomSheet({Key? key}) : super(key: key);

  @override
  _AddBottomSheetState createState() => _AddBottomSheetState();
}

class _AddBottomSheetState extends State<AddBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _topicCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _ytCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _submitText() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.ingestText(_topicCtrl.text, _textCtrl.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submitYoutube() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.ingestYoutube(_topicCtrl.text, _ytCtrl.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'txt']);
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        File file = File(result.files.single.path!);
        await ApiService.ingestFile(_topicCtrl.text, file);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.greenAccent,
            tabs: const [
              Tab(text: "Notes"),
              Tab(text: "Video"),
              Tab(text: "File"),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _topicCtrl, decoration: const InputDecoration(labelText: "Topic Name (e.g. History)")),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : TabBarView(
              controller: _tabController,
              children: [
                // Notes Tab
                Column(
                  children: [
                    Expanded(child: TextField(controller: _textCtrl, maxLines: 5, decoration: const InputDecoration(hintText: "Paste your raw notes here..."))),
                    ElevatedButton(onPressed: _submitText, child: const Text("Ingest via AI"))
                  ],
                ),
                // Video Tab
                Column(
                  children: [
                    TextField(controller: _ytCtrl, decoration: const InputDecoration(labelText: "YouTube URL")),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _submitYoutube, child: const Text("Ingest Video Transcript"))
                  ],
                ),
                // File Tab
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickAndUploadFile, 
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Pick PDF or TXT")
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// SUMMARY SCREEN (Audio playback)
// ----------------------------------------------------
class SummaryScreen extends StatefulWidget {
  final NotificationDetail notification;
  const SummaryScreen({Key? key, required this.notification}) : super(key: key);

  @override
  _SummaryScreenState createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Auto play audio payload from backend
    _player.play(UrlSource(widget.notification.audioUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Audio Summary")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.headphones_rounded, size: 80, color: Colors.greenAccent),
              const SizedBox(height: 24),
              Text(widget.notification.topicName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(widget.notification.summaryText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: () {
                    ApiService.reviewFlashcard(widget.notification.flashcardId, 'remembered');
                    Navigator.pop(context);
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Got It")),
                  ElevatedButton(onPressed: () {
                    ApiService.reviewFlashcard(widget.notification.flashcardId, 'hard');
                    Navigator.pop(context);
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text("Hard")),
                  ElevatedButton(onPressed: () {
                    ApiService.reviewFlashcard(widget.notification.flashcardId, 'forgot');
                    Navigator.pop(context);
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Forgot")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// QUIZ SCREEN
// ----------------------------------------------------
class QuizScreen extends StatelessWidget {
  final String flashcardId;
  final String question;

  const QuizScreen({Key? key, required this.flashcardId, required this.question}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recall Quiz")),
      body: Container(
        color: Colors.red.shade900.withOpacity(0.2),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 24),
            const Text("CRITICAL DECAY", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ApiService.reviewFlashcard(flashcardId, 'remembered');
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
              child: const Text("I Remembered"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ApiService.reviewFlashcard(flashcardId, 'forgot');
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 50)),
              child: const Text("I Forgot"),
            ),
            const SizedBox(height: 40)
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// AUDIO REVIEW SCREEN - Pick a topic to listen
// ----------------------------------------------------
class AudioReviewScreen extends StatefulWidget {
  final List<Topic> flashcards;
  const AudioReviewScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  _AudioReviewScreenState createState() => _AudioReviewScreenState();
}

class _AudioReviewScreenState extends State<AudioReviewScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;

  List<Topic> get _activeCards => widget.flashcards;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _playTopic(Topic topic) async {
    setState(() => _playingId = topic.id);
    try {
      // Try backend gTTS audio
      await _player.play(UrlSource('${AppConstants.backendUrl}/audio/${topic.id}'));
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingId = null);
      });
    } catch (e) {
      // If backend fails, still mark as playing briefly
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _playingId = null);
      });
    }
  }

  void _playAll() async {
    for (final topic in _activeCards) {
      if (!mounted) break;
      setState(() => _playingId = topic.id);
      try {
        await _player.play(UrlSource('${AppConstants.backendUrl}/audio/${topic.id}'));
        // Wait for completion
        await _player.onPlayerComplete.first;
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (mounted) setState(() => _playingId = null);
  }

  void _stop() {
    _player.stop();
    setState(() => _playingId = null);
  }

  Color _urgencyColor(String level) {
    switch (level) {
      case 'critical': return Colors.redAccent;
      case 'danger': return Colors.orange;
      case 'warning': return Colors.amber;
      default: return const Color(0xFF8DA290);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        title: const Text("Audio Review", style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
        backgroundColor: const Color(0xFF0F0F11),
        actions: [
          if (_playingId != null)
            IconButton(icon: const Icon(Icons.stop_circle, color: Colors.redAccent), onPressed: _stop),
        ],
      ),
      body: _activeCards.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.headphones, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No Topics Yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
                SizedBox(height: 8),
                Text("Upload content first to generate audio summaries.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF0F0F11),
            child: Column(
              children: [
                const Text("Pick a topic to listen to its audio summary", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                // Play All button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _playingId == null ? _playAll : _stop,
                    icon: Icon(_playingId == null ? Icons.play_arrow : Icons.stop, size: 20),
                    label: Text(_playingId == null ? "PLAY ALL TOPICS" : "STOP", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),

          // Topic list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activeCards.length,
              itemBuilder: (context, index) {
                final topic = _activeCards[index];
                final isPlaying = _playingId == topic.id;
                return GestureDetector(
                  onTap: () => _playTopic(topic),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isPlaying ? const Color(0xFFC5A059).withAlpha(15) : const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isPlaying ? const Color(0xFFC5A059).withAlpha(80) : Colors.white10),
                    ),
                    child: Row(
                      children: [
                        // Play icon
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isPlaying ? const Color(0xFFC5A059) : Colors.white.withAlpha(8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPlaying ? const Color(0xFFC5A059) : Colors.white10),
                          ),
                          child: Icon(
                            isPlaying ? Icons.volume_up : Icons.play_arrow,
                            color: isPlaying ? Colors.black : Colors.grey,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Topic info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(topic.topicName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF4F1EA))),
                              const SizedBox(height: 4),
                              Text(topic.question, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Retention badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _urgencyColor(topic.urgencyLevel).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _urgencyColor(topic.urgencyLevel).withAlpha(60)),
                          ),
                          child: Text("${topic.retentionScore}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _urgencyColor(topic.urgencyLevel))),
                        ),
                      ],
                    ),
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

// ----------------------------------------------------
// SETTINGS SCREEN
// ----------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _demoMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Output Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Demo Time Compression"),
            subtitle: const Text("Simulates 24 hours of memory decay in 1 minute. Used for hackathon demo."),
            value: _demoMode,
            onChanged: (val) {
              setState(() => _demoMode = val);
              ApiService.setDemoMode(val);
            },
          ),
          ListTile(
            title: const Text("Clear notification queue"),
            onTap: () {
              ApiService.clearAllNotifications();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cleared queues")));
            },
            trailing: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }
}
