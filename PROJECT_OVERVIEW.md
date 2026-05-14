# MemoryForge V2: Adaptive Memory Retention System

## 1. Project Vision
MemoryForge is a production-ready "Memory-as-a-Service" platform. It uses AI to ingest content (PDFs, YouTube, Text), calculates optimal review intervals using Ebbinghaus Forgetting Curve principles, and escalates reminders across a Dashboard and Flutter Mobile App.

---

## 2. Architecture Overview
The system is split into three core modules:

### A. Python Backend (FastAPI)
*   **Role:** The "Brain" of the system.
*   **Key Features Built So Far:**
    *   **AI Ingestion:** Summarizes content via Gemini to create smart flashcards.
    *   **Curve Engine:** Calculates `retention_score` to determine memory decay.
    *   **Escalation Logic:** Categorizes memory states (`Safe`, `Warning`, `Danger`, `Critical`).
    *   **Audio Generation:** Generates MP3 audio overviews of knowledge notes using gTTS.
    *   **WebSockets:** Streams real-time logs to the Dashboard.

### B. React Dashboard (Vite + Tailwind)
*   **Role:** Admin console and visualizer.
*   **Key Features Built So Far:**
    *   **Audio Overview Playback:** Play and stop generated audio summaries for individual flashcards directly from the UI.
    *   **Live Charts:** Visual retention tracking using Recharts.
    *   **Live Logs:** Real-time WebSocket connection to backend activity.
    *   **Note Management:** Manual overrides and content controls.

### C. Flutter Mobile App
*   **Role:** The "Edge" delivery system.
*   **Key Features Built So Far:**
    *   **Quick Add:** Smart Modal ingestion for creating notes.
    *   **Local Polling:** Checks for pending notifications every 5 seconds.
    *   **Alerts:** Native MaterialBanners when retention drops into Warning/Danger zones.

---

## 3. Tech Stack
| Component | Technology |
| :--- | :--- |
| **Backend** | Python, FastAPI, gTTS, Google Gemini |
| **Database** | JSON (Flat-file for portability) |
| **Dashboard** | React 19, Vite, Tailwind CSS, Recharts |
| **Mobile** | Flutter (Dart) |

---

## 4. Setup Instructions (Team Quickstart)

### Prerequisites
*   Python 3.10+
*   Node.js (LTS)
*   Flutter SDK
*   Gemini API Key

### Backend Setup
```bash
cd backend
pip install -r requirements.txt
# Create .env file
echo "GEMINI_API_KEY=your_key_here" > .env
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Dashboard Setup
```bash
cd dashboard
npm install
npm run dev
```

### Flutter Setup
1.  Open `flutter_app/lib/constants.dart`.
2.  Change `laptopIp` to your machine's local IP (find via `ipconfig`).
3.  Run:
```bash
cd flutter_app
flutter pub get
flutter run
```

---

## 5. Development Roadmap
1.  **Phase 1:** local network polling (Current).
2.  **Phase 2:** Cloud sync and persistent PostgreSQL database.
3.  **Phase 3:** Advanced AI voice conversations for active recall testing.

---
*Created for the MemoryForge Development Team.*
