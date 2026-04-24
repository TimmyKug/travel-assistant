"""
Gemini Flash client with daily rate-limit enforcement.
Free tier: 500 requests/day tracked in Firestore.
"""

import asyncio
import logging
import os
import time
from datetime import date

import google.generativeai as genai
from fastapi import HTTPException, status
from google.cloud import firestore

from metrics import ai_requests_total, gemini_duration_seconds
from services.firestore_client import get_db

logger = logging.getLogger(__name__)

DAILY_LIMIT = 500
DEFAULT_MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-3.1-flash-lite-preview")
REASONING_MODEL_NAME = os.getenv("GEMINI_REASONING_MODEL", "gemini-2.5-flash")
USE_REASONING = os.getenv("GEMINI_USE_REASONING", "0") == "1"
MODEL_NAME = REASONING_MODEL_NAME if USE_REASONING else DEFAULT_MODEL_NAME
REQUEST_TIMEOUT_SECONDS = float(os.getenv("GEMINI_REQUEST_TIMEOUT_SECONDS", "30"))

SYSTEM_PROMPT = """You are a travel-planning assistant running a strict two-phase workflow.

Phase 1 (Preference Discovery):
- Ask concise questions to collect trip preferences: destination, dates/length, budget level, traveler type, pace, interests, accommodation preferences, transport preferences, dietary constraints, and must-see priorities.
- Keep responses concise and practical.
- In this phase, DO NOT generate the itinerary JSON.
- When enough context is collected, ask the user to type exactly GO to generate the itinerary.
- If the user has not typed GO yet, stay in Phase 1.

Phase 2 (Itinerary Generation):
- Trigger only after the user message is exactly GO (case-insensitive, surrounding whitespace allowed).
- Return ONLY valid JSON and nothing else (no markdown, no explanation, no code fences).
- Your top-level output must always use this envelope:
{
  "triptitle": "string",
  "response": <phase output>,
  "recommendations": ["string", "string"]
}
- Do not return empty strings for any string fields.
- Always provide 2 to 4 short, clickable suggestion prompts in recommendations
  that fit the current phase and context.
- Recommendations must be user utterances the user can click/send next.
  They must NOT be assistant questions or assistant-offer wording.
  Example good: "I want a 3-day Rome budget itinerary with food highlights."
  Example bad: "What is your budget?" / "Tell me your preferences."
- For every reply, set "triptitle" to an up-to-date trip/topic label and update it
  whenever the topic changes.
- The "response" object must use this exact shape:
{
  "trip_title": "string",
  "destination": "string",
  "summary": "string",
  "hotels": [
    {
      "night": 1,
      "date": "optional string",
      "options": [
        {
          "name": "string",
          "area": "string",
          "nightly_estimate": "string",
          "reason": "string"
        }
      ]
    }
  ],
  "days": [
    {
      "day": 1,
      "date": "optional string",
      "items": [
        {
          "time": "HH:MM",
          "title": "string",
          "description": "string",
          "category": "transport|activity|food|hotel|note",
          "estimated_cost": "optional string"
        }
      ]
    }
  ],
  "budget": {
    "currency": "string",
    "estimated_total": "string",
    "notes": "optional string"
  }
}
- In Phase 2, "hotels" must be grouped per night (one entry per itinerary day/night).
- For each night, include 1-3 affordable hotel options in "options".
- Include daily costs across transport, food, activities, and money-saving tips.

In Phase 1, "response" must be a string containing your preference questions.
In Phase 2, "response" must be the itinerary object above.
"""

genai.configure(api_key=os.environ["GEMINI_API_KEY"])
GENERATION_CONFIG = genai.types.GenerationConfig(
    response_mime_type="application/json",
    temperature=0.2,
)
_model = genai.GenerativeModel(
    MODEL_NAME,
    system_instruction=SYSTEM_PROMPT,
    generation_config=GENERATION_CONFIG,
)


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

        # New day resets counter; otherwise increment.
        new_count = 1 if data.get("date") != today else data.get("count", 0) + 1

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
    try:
        await check_and_increment_rate_limit(uid)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            ai_requests_total.labels(status="rate_limited").inc()
            logger.warning("gemini_rate_limited", extra={"uid": uid})
        raise

    # Separate history from the latest message
    history = messages[:-1]
    latest = messages[-1]["parts"][0] if messages else ""

    chat_session = _model.start_chat(history=history)
    t0 = time.perf_counter()
    try:
        response = await asyncio.wait_for(
            asyncio.to_thread(chat_session.send_message, latest),
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        duration = time.perf_counter() - t0
        gemini_duration_seconds.observe(duration)
        ai_requests_total.labels(status="success").inc()
        logger.info("gemini_chat_success", extra={"uid": uid, "duration_s": round(duration, 3)})
        return response.text
    except TimeoutError as exc:
        duration = time.perf_counter() - t0
        gemini_duration_seconds.observe(duration)
        ai_requests_total.labels(status="error").inc()
        logger.warning(
            "gemini_chat_timeout",
            extra={
                "uid": uid,
                "timeout_s": REQUEST_TIMEOUT_SECONDS,
                "duration_s": round(duration, 3),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"Gemini request timed out after {REQUEST_TIMEOUT_SECONDS:.0f}s",
        ) from exc
    except Exception:
        duration = time.perf_counter() - t0
        gemini_duration_seconds.observe(duration)
        ai_requests_total.labels(status="error").inc()
        logger.exception("gemini_chat_error", extra={"uid": uid})
        raise
