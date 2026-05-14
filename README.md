# MemoryForge V2: The Cognitive Operating System

![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![CrewAI](https://img.shields.io/badge/CrewAI-FF4B4B?style=for-the-badge&logo=openai&logoColor=white)

> MemoryForge V2 is a distributed, multi-modal **Cognitive Operating System** that replaces static spacing algorithms with real-time Machine Learning. By fusing PyTorch-driven Half-Life Regression, biometric telemetry, multi-agent Socratic AI debate, and context-aware mobile intelligence, MemoryForge achieves adaptive neural retention at scale.

---

## Core Deep-Tech Architecture

### PyTorch HLR Engine (Half-Life Regression)
Custom neural network (8→64→32→16→1) that predicts your personal `p(recall)` based on:
- Review history & failure velocity
- Semantic difficulty matrices
- Real-time biometric cognitive load
- Session fatigue tracking

The model performs **online learning** — it updates its weights after every review, adapting to YOUR unique forgetting patterns.

### CrewAI Socratic Swarm
When a flashcard is failed 3+ times, a 3-agent autonomous debate triggers:
1. **The Socratic Interrogator** — Probing questions to find the knowledge gap
2. **The Devil's Advocate** — Challenges assumptions, presents counterpoints
3. **The Bridge Synthesizer** — Connects the concept to existing understanding

### Edge-rPPG Biometric Telemetry
Sensor-less Heart Rate Variability (HRV) and BPM tracking. If cognitive load spikes during review, the ML model adjusts the forgetting half-life dynamically.

### Context-Aware Flutter Edge App
Mobile client with accelerometer-based motion detection. Detects walking/driving and auto-switches to hands-free audio-only review mode via gTTS.

### Knowledge Graph Visualization
Force-directed neural graph showing topic connections, retention health per node, and knowledge gaps — available on both web dashboard and mobile.

### Multi-Modal Ingestion Pipeline
- **PDF Documents** — PyPDF2 extraction → Gemini AI flashcard generation
- **YouTube Videos** — Transcript extraction → AI summarization
- **Raw Text** — Direct paste → AI processing
- **Audio Summaries** — Auto-generated via Google TTS for every card

---

## Tech Stack

| Layer | Technologies |
| :--- | :--- |
| **Frontend** | React 19, Vite, TailwindCSS, Recharts, react-force-graph-2d |
| **Backend & ML** | Python 3.12, FastAPI, PyTorch (HLR), CrewAI, WebSockets |
| **AI** | Google Gemini 2.5 Flash (ingestion, Socratic agents, grading) |
| **Mobile** | Flutter (Dart), sensors_plus, audioplayers, shared_preferences |
| **Audio** | Google TTS (gTTS) for summaries, pyttsx3 for system alerts |
| **Database** | JSON flat-file (zero-setup, portable) |
| **Scheduling** | APScheduler (background retention checks every 5s) |

---

## Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    INGESTION PIPELINE                        │
└─────────────────────────────────────────────────────────────┘
User uploads PDF/YouTube/Text
    → Backend extracts content
    → Gemini AI generates 5-8 flashcards
    → Stored in database + Chronos Plan created
    → Audio summary auto-generated (gTTS)

┌─────────────────────────────────────────────────────────────┐
│                    RETENTION ENGINE                          │
└─────────────────────────────────────────────────────────────┘
Scheduler (every 5s)
    → PyTorch HLR predicts p(recall) per card
    → Classifies urgency: Safe/Warning/Danger/Critical
    → Creates notifications for decaying cards
    → Socratic Swarm triggers on 3+ failures

┌─────────────────────────────────────────────────────────────┐
│                    REAL-TIME SYNC                            │
└─────────────────────────────────────────────────────────────┘
Dashboard ←→ WebSocket (full state every 3s)
Mobile ←→ HTTP polling (every 5s) + offline queue
Game results queue locally → sync when server available
```

---

## Features

| Feature | Description |
|---------|-------------|
| **4 Game Modes** | Match, Speed Recall, Type Challenge, Survival — scores affect revision schedule |
| **Knowledge Graph** | Visual network of topic connections with retention colors |
| **Audio Review** | Pick any topic to listen to its AI-generated summary |
| **Forgetting Curve Chart** | Ebbinghaus visualization with spaced repetition resets |
| **ML Engine Dashboard** | Live PyTorch model metrics (accuracy, loss, parameters) |
| **Biometric Panel** | Real-time BPM, HRV, stress level, cognitive load |
| **Offline-First Games** | Games work without server, results sync when connected |
| **Motion-Aware Audio** | Accelerometer detects movement → auto audio mode |
| **Chronos Plans** | 3-stage reinforcement: Audio → Recap → Quiz |
| **Demo Mode** | 1440x time compression (1 min = 24 hours of decay) |

---

## Quick Start

### Prerequisites
- Python 3.12+
- Node.js 18+
- Flutter SDK
- Google Gemini API key

### 1. Backend
```bash
cd backend
pip install -r requirements.txt
```

Create `.env`:
```
GEMINI_API_KEY=your_key_here
LAPTOP_IP=your_wifi_ip
N8N_WEBHOOK_URL=
```

Run:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 2. Dashboard
```bash
cd dashboard
npm install
npm run dev
```
Opens at `http://localhost:5173`

### 3. Mobile App
Update `flutter_app/lib/constants.dart` with your laptop's IP address:
```dart
static const String laptopIp = "YOUR_WIFI_IP";
```

Then:
```bash
cd flutter_app
flutter pub get
flutter run
```

### Finding Your IP
```bash
# Windows
ipconfig
# Look for Wi-Fi IPv4 Address
```

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/flashcards` | GET | All cards with retention scores |
| `/ingest/text` | POST | Ingest plain text |
| `/ingest/youtube` | POST | Ingest YouTube URL |
| `/ingest/file` | POST | Upload PDF/TXT |
| `/flashcard/review` | POST | Submit review (remembered/hard/forgot) |
| `/ml/metrics` | GET | PyTorch model performance |
| `/ml/predict/{id}` | GET | ML recall prediction |
| `/socratic/{id}` | GET | Trigger 3-agent debate |
| `/biometrics` | GET | Live biometric telemetry |
| `/knowledge-graph` | GET | Graph data for visualization |
| `/audio/{id}` | GET | Stream audio summary |
| `/learning-plans` | GET | All Chronos plans |
| `/notifications/pending` | GET | Pending decay alerts |
| `/ws` | WebSocket | Real-time state broadcast |

---

## Key Algorithms

### Half-Life Regression
```
p(recall) = 2^(-elapsed_time / half_life)
half_life = predicted by PyTorch neural network
```

### Stability Updates (on review)
- **Remembered**: stability × 2.0 (max 720h)
- **Hard**: stability × 1.2
- **Forgot**: stability = 24h (reset) + Socratic trigger at 3 failures

### Urgency Classification
- **Safe**: ≥70% retention
- **Warning**: 50-70%
- **Danger**: 30-50%
- **Critical**: <30%

---

## Project Structure
```
├── backend/
│   ├── main.py              # FastAPI server + all endpoints
│   ├── hlr_model.py         # PyTorch Half-Life Regression engine
│   ├── socratic_swarm.py    # CrewAI 3-agent debate system
│   ├── curve_engine.py      # Forgetting curve math
│   ├── ingest.py            # PDF/YouTube/Text → Gemini → Flashcards
│   ├── scheduler.py         # Background retention checks
│   ├── database.py          # JSON database CRUD
│   └── database.json        # Data store
├── dashboard/
│   ├── src/App.jsx          # Main dashboard UI
│   ├── src/SynapticMatchGame.jsx  # 4 game modes
│   ├── src/KnowledgeGraph.jsx     # Force-directed graph
│   └── src/BiometricPanel.jsx     # ML + biometric display
├── flutter_app/
│   ├── lib/main.dart        # Mobile app (Home, Audio, Settings)
│   ├── lib/game_screen.dart # 4 mobile games
│   ├── lib/knowledge_graph_screen.dart  # Mobile graph
│   ├── lib/motion_audio_service.dart    # Accelerometer detection
│   ├── lib/api_service.dart # HTTP client
│   └── lib/models.dart      # Data models
└── README.md
```

---

*Engineered for the limits of human cognition.*
