# 🧠 MemoryForge V2

> An adaptive "Memory-as-a-Service" platform that uses AI and the Ebbinghaus Forgetting Curve to ensure you never forget critical knowledge.

## Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture & Tech Stack](#architecture--tech-stack)
- [UI & Design System](#ui--design-system)
- [Knowledge Ingestion & The Chronos Plan](#knowledge-ingestion--the-chronos-plan)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)

---

## Overview
MemoryForge is a unified memory augmentation ecosystem. It ingests diverse content formats (PDFs, plain text, and YouTube video transcripts), processes them using Google Gemini AI to generate intelligent "flashcard" knowledge nodes, and tracks your neural retention over time. 

By applying a programmatic version of the **Ebbinghaus Forgetting Curve**, the system calculates an exact `retention_score`. As your memory decays, it escalates reminders from passive dashboard warnings to active mobile push notifications, forcing active recall precisely when you are about to forget the information.

---

## Key Features
- **AI-Powered Ingestion Pipeline**: Automatically extract and distill information into Q&A flashcards using Google Gemini 2.5/1.5 Flash. Supports raw text, `.txt`/`.pdf` documents, and YouTube URLs.
- **Ebbinghaus Curve Engine**: A mathematical backend engine calculates memory stability and retention decay dynamically, classifying knowledge into `Safe`, `Warning`, or `Critical` / `Danger` states.
- **Audio Synthesis**: Generates one-sentence, highly memorable audio summaries (using `gTTS`) that can be played directly from the web dashboard.
- **Real-Time Telemetry & Visualization**: A React command center using `Recharts` visualizes memory decay trends in real-time, pulling live data via WebSockets.
- **Cross-Platform Escalation & Polling**: The Flutter mobile app constantly polls the local backend (designed for local network isolation). When a knowledge node hits a critical decay threshold, the app triggers a high-priority "Material Banner" forcing the user to take a recall quiz.
- **Robust Error Handling**: The mobile client features automated `try/catch/finally` blocks and buffer-state management to gracefully handle backend timeouts, network disconnection, and ingestion failures.

---

## Architecture & Tech Stack

| Module | Technology | Purpose |
| :--- | :--- | :--- |
| **Backend** | Python, FastAPI, gTTS, Gemini SDK, PyPDF2 | The "Brain": AI processing, audio generation, WebSocket broadcasting, and math engine. |
| **Dashboard**| React 19, Vite, Tailwind CSS, Recharts | The "Admin Portal": Real-time visualization, file upload portals, and audio playback control. |
| **Mobile** | Flutter (Dart) | The "Edge": Quick ingestion, synchronized UI, and mobile alert delivery via 5s polling. |
| **Database** | JSON | Flat-file storage (`database.json`) for maximum portability and zero-setup deployment. |

---

## UI & Design System

The entire ecosystem (both the React Dashboard and the Flutter Mobile App) utilizes a unified, premium "Cyber-Scholar" design system:
- **Background (Scaffold/Main)**: Deep Charcoal (`#0a0a0b`)
- **Card/Panel Backgrounds**: Slightly raised panel (`#0f0f11`)
- **Primary Accent**: Muted Gold (`#c5a059`) for primary actions, selected states, and stable trends.
- **Typography**: Off-White (`#f4f1ea`) for primary text, paired with a muted greenish-grey (`#8da290`) for secondary information and positive states.
- **Critical Alerts**: Rose/Red (`#f43f5e`) to signal immediate memory decay requiring user intervention.

---

## Knowledge Ingestion & The Chronos Plan

Whenever new data is uploaded to the dashboard, it is pushed through the AI pipeline and assigned a **Chronos Plan**. This is a multi-stage reinforcement schedule:
1. **Stage 0 (Immediate)**: An Audio Summary is generated instantly for rapid playback.
2. **Stage 1 (T + 1 Hour)**: A Textual Recap is scheduled.
3. **Stage 2 (T + 24 Hours)**: The Knowledge Quiz is unlocked, requiring the user to prove retention.

---

## Prerequisites
Ensure you have the following installed before starting:
- **Python 3.10+** (For the FastAPI Backend)
- **Node.js LTS** (For the React Dashboard)
- **Flutter SDK** (For the Mobile App)
- A valid **Google Gemini API Key**

---

## Installation & Setup

### 1. Backend (FastAPI)
The core intelligence engine.
```bash
cd backend
pip install -r requirements.txt
```
Create a `.env` file in the `backend/` directory:
```env
GEMINI_API_KEY=your_gemini_api_key_here
LAPTOP_IP=your_local_ip_address_here # e.g., 172.20.2.68
```
Run the server:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Dashboard (React)
The visual command center.
```bash
cd dashboard
npm install
npm run dev
```
Access the dashboard at `http://localhost:5173`.

### 3. Mobile App (Flutter)
The alert delivery system.
1. Open `flutter_app/lib/constants.dart`.
2. Update the `laptopIp` variable to match your computer's local IP address (find using `ipconfig` on Windows or `ifconfig` on Mac/Linux).
3. Run the app:
```bash
cd flutter_app
flutter pub get
flutter run
```

---
*Developed for the MemoryForge ecosystem.*
