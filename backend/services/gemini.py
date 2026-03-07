"""
Gemini Flash client with daily rate-limit enforcement.
Free tier: 500 requests/day tracked in Firestore.
"""
import os
from datetime import date, datetime, timezone

import google.generativeai as genai
from fastapi import HTTPException, status
from google.cloud import firestore

from services.firestore_client import get_db

DAILY_LIMIT = 500
MODEL_NAME  = "gemini-3.1-flash-lite-preview"

SYSTEM_PROMPT = """You are an expert AI travel assistant. You help users plan trips,
find destinations, suggest itineraries, recommend restaurants and hotels, and answer
travel-related questions. Be concise, friendly, and practical.
Always consider budget, travel time, and personal preferences when making recommendations.
Use relevant emojis throughout your responses to make them lively and easy to scan —
for example ✈️ for flights, 🏨 for hotels, 🍽️ for restaurants, 🗺️ for itineraries,
💰 for budget tips, 🌍 for destinations, and 📅 for dates/schedules."""

genai.configure(api_key=os.environ["GEMINI_API_KEY"])
_model = genai.GenerativeModel(MODEL_NAME, system_instruction=SYSTEM_PROMPT)


async def check_and_increment_rate_limit(uid: str) -> int:
    """
    Atomically check and increment the daily request counter in Firestore.
    Returns the new count. Raises 429 if limit is exceeded.
    """
    db = get_db()
    today = date.today().isoformat()
    ref = db.collection("rate_limits").document(uid)

    @firestore.transactional
    def update_in_transaction(transaction, ref):
        snapshot = ref.get(transaction=transaction)
        data = snapshot.to_dict() if snapshot.exists else {}

        if data.get("date") != today:
            # New day — reset counter
            new_count = 1
        else:
            new_count = data.get("count", 0) + 1

        if new_count > DAILY_LIMIT:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Daily Gemini API limit of {DAILY_LIMIT} requests reached. Resets at midnight UTC.",
            )

        transaction.set(ref, {"date": today, "count": new_count})
        return new_count

    transaction = db.transaction()
    return update_in_transaction(transaction, ref)


async def chat(uid: str, messages: list[dict]) -> str:
    """
    Send a conversation to Gemini and return the assistant reply.
    messages format: [{"role": "user"|"model", "parts": ["text..."]}]
    """
    await check_and_increment_rate_limit(uid)

    # Separate history from the latest message
    history = messages[:-1]
    latest  = messages[-1]["parts"][0] if messages else ""

    chat_session = _model.start_chat(history=history)
    response = chat_session.send_message(latest)
    return response.text
