# MemoryForge V2: Adaptive Memory Retention System

## 1. Project Vision
MemoryForge is a production-ready "Memory-as-a-Service" platform. It uses AI to ingest content (PDFs, YouTube, Text), calculates optimal review intervals using Ebbinghaus Forgetting Curve principles, and escalates reminders across a Dashboard and Flutter Mobile App.

---

## 2. Architecture Overview
The system is split into three core modules:

### A. Python Backend (FastAPI)
*   **Role:** The "Brain" of the system.
*   **Key Features:**
    *   **AI Ingestion:** Uses Google Gemini to summarize content and generate smart flashcards.
    *   **Curve Engine:** Calculates `retention_score` based on time elapsed since last review.
    *   **Escalation Logic:** 
        *   `Safe`: Retention > 70%
        *   `Warning`: 40-70% (Dashboard Alert)
        *   `Danger`: 15-40% (App Notification)
        *   `Critical`: < 15% (High-priority escalation)
    *   **Audio Generation:** gTTS creates MP3 summaries for passive listening.
    *   **WebSockets:** Pushes real-time logs and metrics to the Dashboard.

### B. React Dashboard (Vite + Tailwind)
*   **Role:** Admin console and visualizer.
*   **Key Features:**
    *   Live retention charts using **Recharts**.
    *   Real-time system log streaming via WebSockets.
    *   Manual curve overrides and content management.

### C. Flutter Mobile App
*   **Role:** The "Edge" delivery system.
*   **Key Features:**
    *   Smart Modal ingestion for adding notes on the go.
    *   **5s Local Polling:** Hits the backend `notifications/pending` endpoint every 5 seconds.
    *   Native MaterialBanner alerts when cards decay into "Warning" or "Danger" zones.

---

## 3. Tech Stack
| Component | Technology |
| :--- | :--- |
| **Backend** | Python, FastAPI, APScheduler, gTTS, Gemini AI |
| **Database** | JSON (Flat-file for portability) |
| **Dashboard** | React 19, Vite, Tailwind CSS, Recharts |
| **Mobile** | Flutter (Dart) |
| **Automation** | n8n (Optional Push Fallback) |

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
