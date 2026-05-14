"""
Daily Summary Email Service
============================
Sends end-of-day email with:
- Topics completed (reviewed today)
- Topics still pending (not reviewed / critical decay)
- Overall retention stats
"""

import smtplib
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import database
import curve_engine
import os
from dotenv import load_dotenv

load_dotenv()

# Email config (Gmail SMTP)
SMTP_EMAIL = os.getenv("SMTP_EMAIL", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")  # App password for Gmail
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
RECIPIENT_EMAIL = os.getenv("RECIPIENT_EMAIL", "")


def generate_daily_summary() -> dict:
    """Generate daily summary data."""
    flashcards = database.get_all_flashcards()
    demo_mode = database.get_demo_mode()
    now = time.time()
    today_start = now - 86400  # Last 24 hours

    completed = []
    pending = []
    critical = []

    for fc in flashcards:
        retention = curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)
        score = curve_engine.calculate_score(retention)
        urgency = curve_engine.get_urgency(score)

        card_info = {
            "topic": fc.get("topic_name", "Unknown"),
            "question": fc.get("question", ""),
            "retention_score": score,
            "urgency": urgency,
            "last_reviewed": fc.get("last_reviewed", 0),
        }

        # Reviewed in last 24 hours = completed
        if fc.get("last_reviewed", 0) > today_start:
            completed.append(card_info)
        elif score < 30:
            critical.append(card_info)
        else:
            pending.append(card_info)

    total = len(flashcards)
    avg_retention = sum(curve_engine.calculate_score(curve_engine.calculate_retention(fc["last_reviewed"], fc["stability"], demo_mode)) for fc in flashcards) / max(total, 1)

    return {
        "total_cards": total,
        "completed_today": len(completed),
        "pending": len(pending),
        "critical": len(critical),
        "avg_retention": round(avg_retention, 1),
        "completed_list": completed[:10],
        "pending_list": pending[:10],
        "critical_list": critical[:10],
        "generated_at": now,
    }


def build_email_html(summary: dict) -> str:
    """Build HTML email content."""
    completed_rows = ""
    for c in summary["completed_list"]:
        completed_rows += f'<tr><td style="padding:8px;border-bottom:1px solid #222;">{c["topic"]}</td><td style="padding:8px;border-bottom:1px solid #222;color:#8da290;">{c["retention_score"]}%</td></tr>'

    pending_rows = ""
    for p in summary["pending_list"]:
        color = "#f43f5e" if p["urgency"] == "critical" else "#f59e0b" if p["urgency"] in ["warning", "danger"] else "#8da290"
        pending_rows += f'<tr><td style="padding:8px;border-bottom:1px solid #222;">{p["topic"]}</td><td style="padding:8px;border-bottom:1px solid #222;color:{color};">{p["retention_score"]}% ({p["urgency"]})</td></tr>'

    critical_rows = ""
    for c in summary["critical_list"]:
        critical_rows += f'<tr><td style="padding:8px;border-bottom:1px solid #222;color:#f43f5e;">{c["topic"]}</td><td style="padding:8px;border-bottom:1px solid #222;color:#f43f5e;">{c["retention_score"]}%</td></tr>'

    html = f"""
    <div style="font-family:Georgia,serif;max-width:600px;margin:0 auto;background:#0a0a0b;color:#f4f1ea;padding:40px;border-radius:20px;">
        <div style="text-align:center;margin-bottom:30px;">
            <h1 style="color:#c5a059;margin:0;">MemoryForge</h1>
            <p style="color:#8da290;font-size:11px;letter-spacing:3px;margin-top:5px;">DAILY COGNITIVE REPORT</p>
        </div>

        <div style="display:flex;gap:10px;margin-bottom:30px;">
            <div style="flex:1;background:#0f0f11;padding:20px;border-radius:12px;text-align:center;border:1px solid #222;">
                <p style="font-size:28px;font-weight:bold;color:#c5a059;margin:0;">{summary['completed_today']}</p>
                <p style="font-size:10px;color:#666;margin:5px 0 0;">COMPLETED</p>
            </div>
            <div style="flex:1;background:#0f0f11;padding:20px;border-radius:12px;text-align:center;border:1px solid #222;">
                <p style="font-size:28px;font-weight:bold;color:#f59e0b;margin:0;">{summary['pending']}</p>
                <p style="font-size:10px;color:#666;margin:5px 0 0;">PENDING</p>
            </div>
            <div style="flex:1;background:#0f0f11;padding:20px;border-radius:12px;text-align:center;border:1px solid #222;">
                <p style="font-size:28px;font-weight:bold;color:#f43f5e;margin:0;">{summary['critical']}</p>
                <p style="font-size:10px;color:#666;margin:5px 0 0;">CRITICAL</p>
            </div>
        </div>

        <p style="color:#8da290;font-size:13px;">Average Retention: <strong>{summary['avg_retention']}%</strong></p>

        {'<h3 style="color:#8da290;font-size:14px;margin-top:30px;">✅ Completed Today</h3><table style="width:100%;border-collapse:collapse;font-size:13px;">' + completed_rows + '</table>' if completed_rows else ''}

        {'<h3 style="color:#f43f5e;font-size:14px;margin-top:30px;">⚠️ Critical Decay (Needs Review)</h3><table style="width:100%;border-collapse:collapse;font-size:13px;">' + critical_rows + '</table>' if critical_rows else ''}

        {'<h3 style="color:#f59e0b;font-size:14px;margin-top:30px;">📋 Pending Review</h3><table style="width:100%;border-collapse:collapse;font-size:13px;">' + pending_rows + '</table>' if pending_rows else ''}

        <div style="margin-top:40px;text-align:center;padding-top:20px;border-top:1px solid #222;">
            <p style="color:#666;font-size:11px;">Engineered for the limits of human cognition.</p>
        </div>
    </div>
    """
    return html


def send_daily_email(recipient: str = None) -> dict:
    """Send the daily summary email."""
    to_email = recipient or RECIPIENT_EMAIL
    if not to_email:
        return {"error": "No recipient email configured"}
    if not SMTP_EMAIL or not SMTP_PASSWORD:
        return {"error": "SMTP not configured. Set SMTP_EMAIL and SMTP_PASSWORD in .env"}

    summary = generate_daily_summary()
    html = build_email_html(summary)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"MemoryForge Daily Report — {summary['completed_today']} completed, {summary['critical']} critical"
    msg["From"] = SMTP_EMAIL
    msg["To"] = to_email
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.sendmail(SMTP_EMAIL, to_email, msg.as_string())
        
        database.add_event(f"Daily email sent to {to_email}")
        return {"success": True, "recipient": to_email, "summary": summary}
    except Exception as e:
        return {"error": f"Email failed: {str(e)}"}
