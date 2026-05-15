"""
CrewAI Socratic Swarm - 3-Agent Debate System
===============================================
When a flashcard is failed 3+ times, this triggers a multi-agent AI debate
to break down the user's misconception using Socratic method.

Agents:
1. The Socratic Interrogator - Asks probing questions to find the gap
2. The Devil's Advocate - Challenges assumptions and presents counterpoints  
3. The Bridge Synthesizer - Connects the concept to things the user already knows
"""

import os
import json
from dotenv import load_dotenv
from google import genai

load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")
client = None
if API_KEY:
    client = genai.Client(api_key=API_KEY)

MODEL = "gemini-2.5-flash"
FALLBACK_MODEL = "gemini-1.5-flash"


def _call_gemini(prompt: str) -> str:
    """Call Gemini with fallback."""
    if not client:
        return "[AI unavailable - check GEMINI_API_KEY]"
    
    for model in [MODEL, FALLBACK_MODEL]:
        try:
            response = client.models.generate_content(model=model, contents=prompt)
            return response.text.strip()
        except Exception as e:
            if '503' in str(e) or 'UNAVAILABLE' in str(e):
                continue
            return f"[Error: {str(e)[:100]}]"
    return "[All models unavailable. Try again later.]"


def trigger_socratic_swarm(question: str, answer: str, topic_name: str, failure_count: int = 3) -> dict:
    """
    Triggers the 3-agent Socratic Swarm debate.
    
    Returns:
        {
            "triggered": True,
            "topic": str,
            "failure_count": int,
            "agents": [
                {"role": "interrogator", "name": "The Socratic Interrogator", "response": str},
                {"role": "advocate", "name": "The Devil's Advocate", "response": str},
                {"role": "synthesizer", "name": "The Bridge Synthesizer", "response": str},
            ],
            "breakthrough": str,  # Final synthesized understanding
            "new_mnemonics": [str],  # Memory aids generated
        }
    """
    
    # Agent 1: The Socratic Interrogator
    interrogator_prompt = f"""You are "The Socratic Interrogator" — an AI agent in a learning system.

A student has FAILED to recall this concept {failure_count} times:
Topic: {topic_name}
Question: {question}
Correct Answer: {answer}

Your job: Ask 2-3 probing questions that help identify WHERE the student's understanding breaks down.
Don't give the answer. Use the Socratic method — guide them to discover the gap.

Be concise (3-4 sentences max). Use a wise, patient tone."""

    interrogator_response = _call_gemini(interrogator_prompt)

    # Agent 2: The Devil's Advocate
    advocate_prompt = f"""You are "The Devil's Advocate" — an AI agent that challenges assumptions.

A student keeps failing this concept:
Topic: {topic_name}
Question: {question}
Correct Answer: {answer}

The Socratic Interrogator said: {interrogator_response}

Your job: Present a common MISCONCEPTION about this topic that the student likely holds.
Explain why it's wrong in a way that creates an "aha!" moment.

Be provocative but educational (3-4 sentences). Challenge their thinking."""

    advocate_response = _call_gemini(advocate_prompt)

    # Agent 3: The Bridge Synthesizer
    synthesizer_prompt = f"""You are "The Bridge Synthesizer" — an AI agent that connects new knowledge to existing understanding.

A student struggles with:
Topic: {topic_name}
Question: {question}
Correct Answer: {answer}

The Interrogator asked: {interrogator_response}
The Devil's Advocate challenged: {advocate_response}

Your job: 
1. Give a clear, memorable 2-sentence explanation that bridges this concept to everyday experience.
2. Create ONE powerful mnemonic or analogy they'll never forget.
3. Summarize the breakthrough in one sentence.

Be warm, clear, and memorable."""

    synthesizer_response = _call_gemini(synthesizer_prompt)

    # Generate mnemonics
    mnemonic_prompt = f"""Generate 2 short, memorable mnemonics or analogies for:
Topic: {topic_name}
Concept: {question} → {answer}

Return as a JSON array of strings. No markdown, just the array.
Example: ["Mnemonic 1", "Mnemonic 2"]"""

    mnemonic_raw = _call_gemini(mnemonic_prompt)
    try:
        import re
        clean = re.sub(r'```json\s*|\s*```', '', mnemonic_raw).strip()
        mnemonics = json.loads(clean)
    except:
        mnemonics = [mnemonic_raw[:200]]

    return {
        "triggered": True,
        "topic": topic_name,
        "failure_count": failure_count,
        "agents": [
            {
                "role": "interrogator",
                "name": "Athena (The Questioner)",
                "icon": "🦉",
                "response": interrogator_response
            },
            {
                "role": "advocate", 
                "name": "Prometheus (The Challenger)",
                "icon": "🔥",
                "response": advocate_response
            },
            {
                "role": "synthesizer",
                "name": "Hermes (The Connector)", 
                "icon": "⚡",
                "response": synthesizer_response
            },
        ],
        "breakthrough": f"Concept bridged: {topic_name}",
        "new_mnemonics": mnemonics,
    }


def check_and_trigger(flashcard: dict) -> dict | None:
    """
    Check if a flashcard should trigger the Socratic Swarm.
    Triggers when ignore_count >= 3 (failed 3+ times).
    """
    ignore_count = flashcard.get("ignore_count", 0)
    if ignore_count >= 3:
        return trigger_socratic_swarm(
            question=flashcard.get("question", ""),
            answer=flashcard.get("answer", ""),
            topic_name=flashcard.get("topic_name", "Unknown"),
            failure_count=ignore_count
        )
    return None
