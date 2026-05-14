import os
import time
import asyncio
from uuid import uuid4
from typing import Annotated, List
from fastapi import FastAPI, BackgroundTasks, UploadFile, File, Form, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import database
import curve_engine
import ingest
from scheduler import start_scheduler
from hlr_model import get_engine as get_hlr_engine
import socratic_swarm

import pyttsx3

app = FastAPI(title="MemoryForge API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    database.init_db()
    start_scheduler()

# -----------------
# MODELS
# -----------------
class AddFlashcardReq(BaseModel):
    topic_name: str
    question: str
    answer: str
    source_type: str = "manual"

class ReviewReq(BaseModel):
    flashcard_id: str
    result: str

class TextIngestReq(BaseModel):
    text: str
    topic_name: str

class YoutubeIngestReq(BaseModel):
    url: str
    topic_name: str

class ClearNotifReq(BaseModel):
    notification_id: str

class DemoToggleReq(BaseModel):
    enabled: bool

class SpeakReq(BaseModel):
    text: str
    urgency: str = "critical"

# -----------------
# FLASHCARD ENDPOINTS
# -----------------
@app.post("/flashcard/add")
def add_flashcard(req: AddFlashcardReq, background_tasks: BackgroundTasks):
    fc = {
        "id": "fc_" + str(uuid4())[:8],
        "topic_name": req.topic_name,
        "question": req.question,
        "answer": req.answer,
        "source_type": req.source_type,
        "created_at": time.time(),
        "last_reviewed": time.time(),
        "stability": 24.0,
        "review_count": 0,
        "ignore_count": 0,
        "status": "active",
        "summary": "",
        "audio_ready": False
    }
    database.add_flashcard(fc)
    database.add_event(f"Added Manual: {req.topic_name}")
    
    background_tasks.add_task(ingest.generate_audio, fc["id"], req.question, req.answer)
    return fc

@app.get("/flashcards")
def get_flashcards():
    flashcards = database.get_all_flashcards()
    demo_mode = database.get_demo_mode()
    
    enriched = []
    for fc in flashcards:
        retention = curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)
        score = curve_engine.calculate_score(retention)
        urgency = curve_engine.get_urgency(score)
        
        fc_enriched = dict(fc)
        fc_enriched["retention_score"] = score
        fc_enriched["urgency_level"] = urgency
        fc_enriched["next_reminder_minutes"] = curve_engine.get_next_reminder_minutes(fc["stability"], demo_mode)
        fc_enriched["curve_points"] = curve_engine.get_curve_points(fc["last_reviewed"], fc["stability"], demo_mode)
        enriched.append(fc_enriched)
        
    return enriched

@app.get("/flashcard/{id}")
def get_flashcard(id: str):
    cards = get_flashcards()
    for c in cards:
        if c["id"] == id:
            return c
    raise HTTPException(status_code=404, detail="Flashcard not found")

@app.get("/flashcard/{id}/status")
def get_flashcard_status(id: str):
    c = get_flashcard(id)
    return {
        "id": c["id"],
        "retention_score": c["retention_score"],
        "urgency_level": c["urgency_level"],
        "next_reminder_minutes": c["next_reminder_minutes"]
    }

@app.post("/flashcard/review")
def review_flashcard(req: ReviewReq):
    fc = database.get_flashcard(req.flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    
    # Update HLR model with review outcome (online learning)
    try:
        engine = get_hlr_engine()
        engine.update_on_review(fc, req.result)
    except Exception as e:
        print(f"HLR update error (non-fatal): {e}")
    
    new_stability = curve_engine.update_stability(fc["stability"], req.result)
    
    # Track failures for Socratic Swarm trigger
    ignore_count = fc.get("ignore_count", 0)
    if req.result == "forgot":
        ignore_count += 1
    else:
        ignore_count = 0
    
    updates = {
        "stability": new_stability,
        "last_reviewed": time.time(),
        "review_count": fc.get("review_count", 0) + 1,
        "ignore_count": ignore_count
    }
    database.update_flashcard(req.flashcard_id, updates)
    database.add_event(f"Reviewed: {fc['topic_name']} ({req.result})")
    
    # Clear any pending notification for it
    pending = database.get_pending_notifications()
    for p in pending:
        if p["flashcard_id"] == req.flashcard_id:
            database.clear_notification(p["notification_id"])
    
    result = get_flashcard(req.flashcard_id)
    
    # Check if Socratic Swarm should trigger
    if ignore_count >= 3:
        result["socratic_trigger"] = True
        result["socratic_message"] = f"Failed {ignore_count} times. Socratic Swarm available."
    
    return result

@app.delete("/flashcard/{id}")
def delete_flashcard(id: str):
    success = database.delete_flashcard(id)
    if success:
        return {"success": True}
    raise HTTPException(status_code=404)

# -----------------
# INGEST ENDPOINTS
# -----------------
@app.post("/ingest/text")
def ingest_text_api(req: TextIngestReq):
    try:
        fcs = ingest.ingest_text(req.text, req.topic_name)
        if not fcs:
            raise HTTPException(status_code=500, detail="Gemini failed or returned empty")
        return fcs
    except Exception as e:
        print(f"Ingest Text Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ingest/youtube")
def ingest_youtube_api(req: YoutubeIngestReq):
    try:
        fcs = ingest.ingest_youtube(req.url, req.topic_name)
        if not fcs:
            raise HTTPException(status_code=500, detail="Gemini/YouTube extraction failed")
        return fcs
    except Exception as e:
        print(f"Ingest URL Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ingest/file")
async def ingest_file_api(
    file: Annotated[UploadFile, File(...)], 
    topic_name: Annotated[str, Form(...)]
):
    try:
        contents = await file.read()
        filename_lower = file.filename.lower()
        
        if filename_lower.endswith(".pdf"):
            fcs = ingest.ingest_pdf(contents, topic_name)
        elif filename_lower.endswith(".txt"):
            fcs = ingest.ingest_text(contents.decode('utf-8', errors='ignore'), topic_name)
        else:
            raise HTTPException(status_code=400, detail="Unsupported file format (pdf/txt only)")
            
        if not fcs:
            raise HTTPException(status_code=500, detail="Failed to parse file or AI failed")
            
        return fcs
    except Exception as e:
        print(f"Ingest File Error: {e}")
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

# -----------------
# LEARNING PLAN ENDPOINTS
# -----------------
@app.get("/learning-plans")
def get_learning_plans():
    return database.get_all_learning_plans()

@app.get("/learning-plan/{topic_id}")
def get_learning_plan(topic_id: str):
    plan = database.get_learning_plan(topic_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    return plan

# -----------------
# NOTIFICATION ENDPOINTS
# -----------------
@app.get("/notifications/pending")
def pending_notifications():
    return database.get_pending_notifications()

@app.post("/notifications/clear")
def clear_notification(req: ClearNotifReq):
    database.clear_notification(req.notification_id)
    return {"success": True}

@app.post("/notifications/clear-all")
def clear_all_notifications():
    for p in database.get_pending_notifications():
        database.clear_notification(p["notification_id"])
    return {"success": True}

# -----------------
# AUDIO ENDPOINTS
# -----------------
class AudioGenReq(BaseModel):
    flashcard_id: str

@app.get("/audio/{id}")
def get_audio(id: str):
    path = f"audio/{id}.mp3"
    if not os.path.exists(path):
        fc = database.get_flashcard(id)
        if fc:
            # Generate synchronously if not found
            ingest.generate_audio(id, fc.get("question", ""), fc.get("answer", ""))
        else:
            raise HTTPException(status_code=404, detail="Flashcard not found")
    
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Audio file could not be generated")
    return FileResponse(path, media_type="audio/mpeg")

@app.post("/audio/generate")
def generate_audio_endpoint(req: AudioGenReq, background_tasks: BackgroundTasks):
    fc = database.get_flashcard(req.flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    
    path = f"audio/{req.flashcard_id}.mp3"
    if not os.path.exists(path):
        ingest.generate_audio(req.flashcard_id, fc.get("question", ""), fc.get("answer", ""))
    return {"path": path, "ready": True}

@app.post("/speak")
def speak_endpoint(req: SpeakReq, background_tasks: BackgroundTasks):
    def run_tts(text: str):
        try:
            engine = pyttsx3.init()
            engine.setProperty('rate', 150)
            engine.say(text)
            engine.runAndWait()
        except Exception as e:
            print(f"TTS Error: {e}")
            
    background_tasks.add_task(run_tts, req.text)
    return {"success": True, "message": "Speaking..."}

# -----------------
# SETTINGS
# -----------------
@app.get("/dashboard")
def dashboard_stats():
    cards = get_flashcards()
    total = len(cards)
    critical = sum(1 for c in cards if c["urgency_level"] == "critical")
    warning = sum(1 for c in cards if c["urgency_level"] == "warning")
    return {
        "total_cards": total,
        "critical_cards": critical,
        "warning_cards": warning,
        "demo_mode": database.get_demo_mode(),
        "recent_events": database.get_events(limit=5),
        "active_plans": len([p for p in database.get_all_learning_plans() if p.get("status") == "active"])
    }

@app.get("/events")
def events_endpoint():
    return database.get_events(limit=50)

@app.get("/settings")
def get_settings():
    db_data = database.read_db()
    settings = db_data.get("settings", {})
    return {
        "demo_mode": database.get_demo_mode(),
        "compression_ratio": settings.get("compression_ratio", 1440),
        "laptop_ip": os.getenv("LAPTOP_IP", "127.0.0.1")
    }

class DemoModeReq(BaseModel):
    enabled: bool
    compression_ratio: int

@app.post("/settings/demo-mode")
def toggle_demo(req: DemoModeReq):
    database.set_demo_mode(req.enabled)
    db_data = database.read_db()
    if "settings" not in db_data:
        db_data["settings"] = {}
    db_data["settings"]["compression_ratio"] = req.compression_ratio
    database.write_db(db_data)
    
    state_str = "ON" if req.enabled else "OFF"
    database.add_event(f"Demo mode: {state_str}")
    
    # In a real app we might restart the scheduler here
    from scheduler import start_scheduler
    # scheduler is global in start_scheduler, so this is a simplified restart
    
    return {
        "success": True, 
        "demo_mode": req.enabled, 
        "compression_ratio": req.compression_ratio
    }

# -----------------
# WEBSOCKET
# -----------------
active_connections = []

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            # Broadcast the unified state every 3 seconds
            data = {
                "flashcards": get_flashcards(),
                "learning_plans": database.get_all_learning_plans(),
                "events": database.get_events(limit=10),
                "dashboard": dashboard_stats()
            }
            await websocket.send_json(data)
            await asyncio.sleep(3)
    except WebSocketDisconnect:
        if websocket in active_connections:
            active_connections.remove(websocket)
    except Exception as e:
        print(f"WS Error: {e}")
        if websocket in active_connections:
            active_connections.remove(websocket)

# -----------------
# HLR ML ENGINE ENDPOINTS
# -----------------
@app.get("/ml/metrics")
def ml_metrics():
    """Get PyTorch HLR model performance metrics."""
    engine = get_hlr_engine()
    return engine.get_metrics()

@app.get("/ml/predict/{flashcard_id}")
def ml_predict(flashcard_id: str):
    """Get ML-powered recall prediction for a specific flashcard."""
    fc = database.get_flashcard(flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    engine = get_hlr_engine()
    demo_mode = database.get_demo_mode()
    return engine.predict_recall(fc, demo_mode=demo_mode)

@app.get("/ml/curve/{flashcard_id}")
def ml_curve(flashcard_id: str):
    """Get predicted retention curve from HLR model."""
    fc = database.get_flashcard(flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    engine = get_hlr_engine()
    demo_mode = database.get_demo_mode()
    return engine.get_curve_points(fc, demo_mode=demo_mode)

# -----------------
# SOCRATIC SWARM ENDPOINTS
# -----------------
@app.get("/socratic/{flashcard_id}")
def get_socratic_debate(flashcard_id: str):
    """Trigger Socratic Swarm for a struggling flashcard."""
    fc = database.get_flashcard(flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    
    result = socratic_swarm.trigger_socratic_swarm(
        question=fc.get("question", ""),
        answer=fc.get("answer", ""),
        topic_name=fc.get("topic_name", "Unknown"),
        failure_count=fc.get("ignore_count", 0)
    )
    database.add_event(f"Socratic Swarm triggered: {fc.get('topic_name')}")
    return result

@app.get("/socratic/check/{flashcard_id}")
def check_socratic(flashcard_id: str):
    """Check if a flashcard qualifies for Socratic intervention."""
    fc = database.get_flashcard(flashcard_id)
    if not fc:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    return {
        "qualifies": fc.get("ignore_count", 0) >= 3,
        "failure_count": fc.get("ignore_count", 0),
        "threshold": 3
    }

# -----------------
# BIOMETRIC TELEMETRY (Simulated rPPG)
# -----------------
_biometric_state = {
    "bpm": 72,
    "hrv": 55,
    "stress_level": 0.3,
    "cognitive_load": 0.4,
    "last_updated": time.time()
}

class BiometricUpdate(BaseModel):
    bpm: int = 72
    hrv: int = 55
    stress_level: float = 0.3

@app.get("/biometrics")
def get_biometrics():
    """Get current biometric state (simulated rPPG telemetry)."""
    # Simulate slight variations for realism
    import random
    _biometric_state["bpm"] = max(55, min(120, _biometric_state["bpm"] + random.randint(-3, 3)))
    _biometric_state["hrv"] = max(20, min(90, _biometric_state["hrv"] + random.randint(-2, 2)))
    _biometric_state["stress_level"] = max(0, min(1, _biometric_state["stress_level"] + random.uniform(-0.05, 0.05)))
    _biometric_state["cognitive_load"] = min(1.0, max(0.0, (_biometric_state["bpm"] - 60) / 60.0 * 0.7))
    _biometric_state["last_updated"] = time.time()
    return _biometric_state

@app.post("/biometrics")
def update_biometrics(req: BiometricUpdate):
    """Update biometric state (from webcam rPPG or manual)."""
    _biometric_state["bpm"] = req.bpm
    _biometric_state["hrv"] = req.hrv
    _biometric_state["stress_level"] = req.stress_level
    _biometric_state["cognitive_load"] = min(1.0, max(0.0, (req.bpm - 60) / 60.0 * 0.7))
    _biometric_state["last_updated"] = time.time()
    return _biometric_state

# -----------------
# KNOWLEDGE GRAPH DATA
# -----------------
@app.get("/knowledge-graph")
def knowledge_graph():
    """Generate knowledge graph data from flashcards for visualization."""
    flashcards = database.get_all_flashcards()
    
    # Build nodes (topics) and edges (shared concepts)
    topics = {}
    for fc in flashcards:
        topic = fc.get("topic_name", "Unknown")
        if topic not in topics:
            topics[topic] = {
                "id": topic,
                "cards": 0,
                "avg_retention": 0,
                "total_retention": 0,
            }
        topics[topic]["cards"] += 1
        demo_mode = database.get_demo_mode()
        retention = curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)
        score = curve_engine.calculate_score(retention)
        topics[topic]["total_retention"] += score
    
    nodes = []
    for topic, data in topics.items():
        avg_ret = data["total_retention"] / max(data["cards"], 1)
        nodes.append({
            "id": topic,
            "name": topic,
            "val": data["cards"] * 3 + 5,  # Node size
            "retention": int(avg_ret),
            "cards": data["cards"],
            "color": "#c5a059" if avg_ret >= 70 else "#f59e0b" if avg_ret >= 50 else "#f43f5e"
        })
    
    # Create edges between topics that share keywords
    edges = []
    topic_list = list(topics.keys())
    for i in range(len(topic_list)):
        for j in range(i + 1, len(topic_list)):
            # Simple heuristic: connect topics with shared words
            words_i = set(topic_list[i].lower().split())
            words_j = set(topic_list[j].lower().split())
            if words_i & words_j:
                edges.append({"source": topic_list[i], "target": topic_list[j]})
    
    # If no real data, return demo graph
    if not nodes:
        nodes = [
            {"id": "Philosophy", "name": "Philosophy: Stoicism", "val": 12, "retention": 94, "cards": 3, "color": "#c5a059"},
            {"id": "Quantum", "name": "Quantum Mechanics", "val": 8, "retention": 38, "cards": 2, "color": "#f43f5e"},
            {"id": "React", "name": "React: Performance", "val": 10, "retention": 72, "cards": 2, "color": "#f59e0b"},
            {"id": "Growth", "name": "Growth Strategy", "val": 9, "retention": 55, "cards": 2, "color": "#f59e0b"},
            {"id": "Neuro", "name": "Neuroscience", "val": 14, "retention": 88, "cards": 4, "color": "#c5a059"},
            {"id": "Systems", "name": "Distributed Systems", "val": 11, "retention": 65, "cards": 3, "color": "#f59e0b"},
            {"id": "ML", "name": "Machine Learning", "val": 13, "retention": 78, "cards": 3, "color": "#c5a059"},
            {"id": "OS", "name": "Operating Systems", "val": 7, "retention": 45, "cards": 1, "color": "#f43f5e"},
        ]
        edges = [
            {"source": "Quantum", "target": "Neuro"},
            {"source": "Neuro", "target": "ML"},
            {"source": "ML", "target": "React"},
            {"source": "React", "target": "Systems"},
            {"source": "Systems", "target": "OS"},
            {"source": "Philosophy", "target": "Neuro"},
            {"source": "Growth", "target": "ML"},
            {"source": "Quantum", "target": "ML"},
        ]
    
    return {"nodes": nodes, "links": edges}
