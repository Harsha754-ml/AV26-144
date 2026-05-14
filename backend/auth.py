"""
Simple Auth System - Student & Teacher Roles
=============================================
- Students: upload content, play games, get reviewed
- Teachers: see all students, get alerts when retention < 30% for 3+ days
"""

import time
import database

# Simple in-memory user store (for demo - no password hashing needed)
USERS = {
    "students": {},  # {username: {name, created_at, last_active}}
    "teachers": {},  # {username: {name, created_at, students: []}}
}

def init_users():
    """Load users from database."""
    data = database.read_db()
    if "users" not in data:
        data["users"] = {"students": {}, "teachers": {}}
        database.write_db(data)
    return data["users"]

def save_users(users):
    data = database.read_db()
    data["users"] = users
    database.write_db(data)

def register(username: str, password: str, role: str, name: str = "") -> dict:
    users = init_users()
    
    # Check if exists in either role
    if username in users.get("students", {}) or username in users.get("teachers", {}):
        return {"error": "Username already exists"}
    
    user = {
        "username": username,
        "password": password,  # Plain text for demo
        "name": name or username,
        "role": role,
        "created_at": time.time(),
        "last_active": time.time(),
    }
    
    if role == "teacher":
        user["students"] = []
        users.setdefault("teachers", {})[username] = user
    else:
        users.setdefault("students", {})[username] = user
    
    save_users(users)
    return {"success": True, "user": {k: v for k, v in user.items() if k != "password"}}

def login(username: str, password: str) -> dict:
    users = init_users()
    
    # Check students
    if username in users.get("students", {}):
        user = users["students"][username]
        if user["password"] == password:
            user["last_active"] = time.time()
            save_users(users)
            return {"success": True, "role": "student", "user": {k: v for k, v in user.items() if k != "password"}}
    
    # Check teachers
    if username in users.get("teachers", {}):
        user = users["teachers"][username]
        if user["password"] == password:
            user["last_active"] = time.time()
            save_users(users)
            return {"success": True, "role": "teacher", "user": {k: v for k, v in user.items() if k != "password"}}
    
    return {"error": "Invalid username or password"}

def get_teacher_alerts() -> list:
    """
    Check all students - if any have retention < 30% for 3+ days, alert teacher.
    """
    alerts = []
    flashcards = database.get_all_flashcards()
    now = time.time()
    three_days = 3 * 24 * 3600
    
    # Group cards by topic and check for critical decay
    critical_topics = {}
    for fc in flashcards:
        last_reviewed = fc.get("last_reviewed", now)
        stability = fc.get("stability", 24.0)
        
        # Calculate if card has been critical for 3+ days
        time_since_review = now - last_reviewed
        if time_since_review > three_days and stability < 48:
            topic = fc.get("topic_name", "Unknown")
            if topic not in critical_topics:
                critical_topics[topic] = {"topic": topic, "cards": 0, "days_critical": 0}
            critical_topics[topic]["cards"] += 1
            critical_topics[topic]["days_critical"] = int(time_since_review / 86400)
    
    for topic, info in critical_topics.items():
        alerts.append({
            "type": "critical_decay",
            "topic": info["topic"],
            "cards_affected": info["cards"],
            "days_critical": info["days_critical"],
            "message": f"Student has {info['cards']} cards in '{info['topic']}' with critical decay for {info['days_critical']} days",
            "severity": "high" if info["days_critical"] > 5 else "medium",
            "timestamp": now,
        })
    
    return alerts

def get_student_stats() -> list:
    """Get overview of all student performance for teacher dashboard."""
    flashcards = database.get_all_flashcards()
    
    if not flashcards:
        return []
    
    # Aggregate stats
    import curve_engine
    demo_mode = database.get_demo_mode()
    
    total = len(flashcards)
    scores = []
    critical = 0
    
    for fc in flashcards:
        retention = curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)
        score = curve_engine.calculate_score(retention)
        scores.append(score)
        if score < 30:
            critical += 1
    
    avg_retention = sum(scores) / max(len(scores), 1)
    
    return {
        "total_cards": total,
        "avg_retention": round(avg_retention, 1),
        "critical_cards": critical,
        "healthy_cards": total - critical,
        "needs_attention": critical > total * 0.3,  # More than 30% cards critical
    }
