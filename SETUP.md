# MemoryForge V2 — Setup & Run Guide

## Prerequisites
- Python 3.12+
- Node.js 18+
- Flutter SDK (with Android device/emulator)
- Google Gemini API key

---

## Step 1: Backend

```bash
cd backend
pip install -r requirements.txt
```

**`.env` file** (already configured):
```
GEMINI_API_KEY=your_key
LAPTOP_IP=your_wifi_ip
SMTP_EMAIL=codenexcoding@gmail.com
SMTP_PASSWORD=chus upvj fysk seny
```

**Find your IP:**
```bash
ipconfig
# Use the Wi-Fi IPv4 address
```

**Run:**
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

---

## Step 2: Dashboard

```bash
cd dashboard
npm install
npm run dev
```

Opens at: `http://localhost:5173`

---

## Step 3: Mobile App

**Update IP** in `flutter_app/lib/constants.dart`:
```dart
static const String laptopIp = "YOUR_WIFI_IP";
```

**Run:**
```bash
cd flutter_app
flutter pub get
flutter run
```

**Note:** Phone must be on same Wi-Fi as laptop.

---

## Run Order
1. Backend FIRST (everything depends on it)
2. Dashboard (web)
3. Mobile app

---

## Demo Flow for Jury

### 1. Splash + Login (30s)
- App opens with animated splash
- Click "Continue as Independent Learner" or register

### 2. Upload PDF (1 min)
- Select Document tab → pick PDF → click INITIATE LINK
- Topic name auto-detected from content
- Wait 10-15s for Gemini to generate flashcards
- Cards appear with retention scores

### 3. Show Forgetting Curve (30s)
- Charts appear showing Ebbinghaus decay
- "Without review, 80% forgotten in 7 days"

### 4. Game Mode + Face Detection (2 min) ⭐ KEY DEMO
- Go to Games tab → Speed Recall
- Camera widget appears (bottom-right)
- **Smile** → shows "😊 Confident" → banner: "🚀 Harder card selected"
- **Frown/squint** → shows "🤔 Confused" → banner: "⚡ Easier card selected"
- "Google ML Kit reads facial micro-expressions and adapts questions in real-time"

### 5. ML Engine (30s)
- Show PyTorch HLR metrics (3,201 parameters, online learning)
- Start webcam rPPG → stress/cognitive load displayed
- "Stress affects revision schedule"

### 6. Knowledge Graph (30s)
- 3D WebGL graph with topic nodes
- Colors = retention health

### 7. Audio Review (20s)
- Click any card → "Learn Now" → audio plays → quiz follows

### 8. Email System (20s)
- "Daily report emails at 9 PM — completed, pending, critical"
- Show the email in inbox if already received

---

## Key Talking Points for Jury

| Question | Answer |
|----------|--------|
| "Is the ML real?" | Yes — PyTorch HLR neural net, 8 inputs, online learning after every review |
| "Is the face detection real?" | Yes — Google ML Kit, detects smile probability + eye openness |
| "Does it adapt?" | Yes — confused expression → easier cards, confident → harder cards |
| "How is this different from Anki?" | Anki uses static SM-2 from 1987. We use adaptive ML + biometrics + multi-agent AI |
| "What about the Socratic Swarm?" | Fail a card 3x → 3 AI agents debate your misconception (Gemini-powered) |
| "Does the email work?" | Yes — sends from codenexcoding@gmail.com to user's email daily at 9 PM |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Backend won't start | Check `pip install -r requirements.txt` ran successfully |
| Dashboard blank | Hard refresh `Ctrl+Shift+R` |
| Mobile can't connect | Check IP in constants.dart matches `ipconfig` output |
| Upload stuck | Backend must be running. Check terminal for errors |
| Camera not showing | Allow camera permission in browser/phone |
| Email fails | Verify SMTP credentials in .env |
| Flutter build fails | Run `flutter clean` then `flutter run` |

---

## Tech Stack Summary

```
Backend:  Python + FastAPI + PyTorch + CrewAI + Gemini AI + gTTS
Frontend: React 19 + Vite + TailwindCSS + Three.js + Recharts
Mobile:   Flutter + Google ML Kit + Camera + AudioPlayers + Sensors
Database: JSON flat-file (zero setup)
Email:    Gmail SMTP (auto daily reports)
```
