# 🧠 MemoryForge V2

> An adaptive "Memory-as-a-Service" platform that uses AI and the Ebbinghaus Forgetting Curve to ensure you never forget critical knowledge.

## Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture & Tech Stack](#architecture--tech-stack)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
  - [1. Backend (FastAPI)](#1-backend-fastapi)
  - [2. Dashboard (React)](#2-dashboard-react)
  - [3. Mobile App (Flutter)](#3-mobile-app-flutter)

---

## Overview
MemoryForge ingests content (PDFs, text, YouTube summaries), processes it using Google Gemini AI to generate smart flashcards, and tracks your retention over time. As your memory decays, it escalates reminders from passive dashboard warnings to active mobile push notifications.

---

## Key Features
- **AI-Powered Ingestion**: Automatically summarize and extract flashcards using Google Gemini.
- **Ebbinghaus Curve Engine**: Calculates exact `retention_score` to alert you precisely when you are about to forget.
- **Audio Overviews**: Generate and play MP3 audio summaries of your notes directly in the dashboard.
- **Real-Time Telemetry**: Watch memory decay live on the dashboard with Recharts and WebSockets.
- **Cross-Platform Escalation**: 
  - `Safe` (>70% retention)
  - `Warning` (Dashboard alerts)
  - `Danger` (Flutter Mobile App Native Banners)

---

## Architecture & Tech Stack

| Module | Technology | Purpose |
| :--- | :--- | :--- |
| **Backend** | Python, FastAPI, gTTS, Gemini | The "Brain": AI processing, audio generation, and math engine. |
| **Dashboard**| React 19, Vite, Tailwind CSS | Admin visualizer and control panel. |
| **Mobile** | Flutter (Dart) | The "Edge": Quick ingestion and mobile alerts via 5s polling. |
| **Database** | JSON | Flat-file storage for maximum portability. |

---

## Prerequisites
Ensure you have the following installed before starting:
- **Python 3.10+** (For Backend)
- **Node.js LTS** (For Dashboard)
- **Flutter SDK** (For Mobile App)
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

### 3. Mobile App (Flutter)
The alert delivery system.
1. Open `flutter_app/lib/constants.dart`.
2. Update the `laptopIp` variable to match your computer's local IP address (find using `ipconfig` or `ifconfig`).
3. Run the app:
```bash
cd flutter_app
flutter pub get
flutter run
```

---
*Developed for the MemoryForge ecosystem.*
