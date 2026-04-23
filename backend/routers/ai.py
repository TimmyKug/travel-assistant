"""
AI chat router - wraps Gemini Flash with conversation persistence in Firestore.
"""

import json
import logging
import re
from datetime import UTC, datetime
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from services.firestore_client import get_db
from services.gemini import chat as gemini_chat
from services.jwt_auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)


class MessageIn(BaseModel):
    conversation_id: str | None = None
    content: str
    # Kept for backward compatibility with older clients; backend now enforces JSON phased mode.
    response_format: Literal["text", "trip_json"] = "text"
    is_bootstrap: bool = False


class MessageOut(BaseModel):
    conversation_id: str
    user_message: str
    assistant_message: str
    recommendations: list[str]
    trip_plan: dict[str, Any] | None = None
    created_at: datetime


class ConversationUpdateIn(BaseModel):
    title: str


def _parse_gemini_envelope(reply: str) -> dict[str, Any]:
    raw = _extract_json_block(reply)
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as err:
        raise ValueError("Envelope is not valid JSON") from err

    if not isinstance(data, dict):
        raise ValueError("Envelope root must be an object")

    required_keys = {"triptitle", "response", "recommendations"}
    if set(data.keys()) != required_keys:
        raise ValueError("Envelope must contain exactly triptitle, response, recommendations")

    trip_title = data.get("triptitle")
    response = data.get("response")
    recommendations = data.get("recommendations")

    if not isinstance(trip_title, str) or not trip_title.strip():
        raise ValueError("triptitle must be a non-empty string")
    if response is None:
        raise ValueError("response is required")
    if isinstance(response, str) and not response.strip():
        raise ValueError("response string must be non-empty")
    if not isinstance(recommendations, list) or not (2 <= len(recommendations) <= 4):
        raise ValueError("recommendations must be a list with 2 to 4 items")
    if not all(isinstance(item, str) and item.strip() for item in recommendations):
        raise ValueError("recommendations must contain only non-empty strings")

    return {
        "triptitle": trip_title.strip(),
        "response": response,
        "recommendations": [item.strip() for item in recommendations],
    }


def _response_to_text(response: Any) -> str:
    if isinstance(response, str):
        text = response.strip()
        if text:
            return text
        return "Please share a bit more detail so I can continue."
    return json.dumps(response, ensure_ascii=False)


def _extract_json_block(text: str) -> str:
    fenced_match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, flags=re.DOTALL)
    if fenced_match:
        return fenced_match.group(1)

    # Fallback: scan for the first decodable JSON object in mixed text.
    decoder = json.JSONDecoder()
    stripped = text.strip()
    for idx, ch in enumerate(stripped):
        if ch != "{":
            continue
        try:
            obj, _ = decoder.raw_decode(stripped[idx:])
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            return json.dumps(obj, ensure_ascii=False)

    return stripped


def _repair_instruction_for_envelope(original_request: str) -> str:
    return (
        f"{original_request}\n\n"
        "IMPORTANT: Return only valid JSON (no markdown, no surrounding text) with exactly these keys: "
        "triptitle, response, recommendations. "
        "recommendations must be a list with 2 to 4 non-empty strings."
    )


def _clip_raw_response(value: str, limit: int = 12000) -> str:
    if len(value) <= limit:
        return value
    return f"{value[:limit]}\n...[truncated]"


def _build_contract_violation_detail(
    reason: str,
    first_try: str,
    retry_try: str,
    snippet_limit: int = 1200,
) -> str:
    first_snippet = _clip_raw_response(first_try, snippet_limit)
    retry_snippet = _clip_raw_response(retry_try, snippet_limit)
    return (
        f"Gemini envelope contract violation: {reason}\n"
        f"--- Gemini raw response (first try) ---\n{first_snippet}\n"
        f"--- Gemini raw response (retry) ---\n{retry_snippet}"
    )


def _parse_trip_plan(reply: str) -> dict[str, Any] | None:
    raw = _extract_json_block(reply)
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None

    if not isinstance(data, dict):
        return None
    if "days" not in data or not isinstance(data["days"], list):
        return None
    if "trip_title" not in data or "destination" not in data:
        return None
    return data


@router.post("/chat", response_model=MessageOut)
async def chat(body: MessageIn, user: dict = Depends(get_current_user)):
    db = get_db()
    uid = user["uid"]

    if body.conversation_id:
        conv_ref = (
            db.collection("users")
            .document(uid)
            .collection("conversations")
            .document(body.conversation_id)
        )
        conv_doc = conv_ref.get()
        if not conv_doc.exists:
            raise HTTPException(status_code=404, detail="Conversation not found")
        history = conv_doc.to_dict().get("messages", [])
    else:
        conv_ref = db.collection("users").document(uid).collection("conversations").document()
        history = []

    request_text = body.content

    request_history = [*history, {"role": "user", "parts": [request_text]}]
    logger.info("ai_chat_request", extra={"uid": uid, "conversation_id": conv_ref.id})

    forced_response_format: Literal["trip_json"] = "trip_json"
    raw_reply = await gemini_chat(
        uid=uid, messages=request_history, response_format=forced_response_format
    )
    try:
        envelope = _parse_gemini_envelope(raw_reply)
    except ValueError as first_exc:
        logger.warning(
            "gemini_envelope_invalid_first_try",
            extra={"uid": uid, "conversation_id": conv_ref.id, "reason": str(first_exc)},
        )
        repaired_history = [
            *history,
            {"role": "user", "parts": [_repair_instruction_for_envelope(request_text)]},
        ]
        raw_reply_retry = await gemini_chat(
            uid=uid,
            messages=repaired_history,
            response_format=forced_response_format,
        )
        try:
            envelope = _parse_gemini_envelope(raw_reply_retry)
            raw_reply = raw_reply_retry
        except ValueError as final_exc:
            logger.warning(
                "gemini_envelope_invalid_after_retry",
                extra={"uid": uid, "conversation_id": conv_ref.id, "reason": str(final_exc)},
            )
            return JSONResponse(
                status_code=502,
                content={
                    "detail": _build_contract_violation_detail(
                        reason=str(final_exc),
                        first_try=raw_reply,
                        retry_try=raw_reply_retry,
                    ),
                    "gemini_raw_response": _clip_raw_response(raw_reply_retry),
                    "gemini_raw_response_first_try": _clip_raw_response(raw_reply),
                },
            )

    response_payload = envelope["response"]
    assistant_message = _response_to_text(response_payload)

    if not body.is_bootstrap:
        history.append({"role": "user", "parts": [request_text]})
    history.append({"role": "model", "parts": [assistant_message]})

    trip_plan: dict[str, Any] | None = None
    if isinstance(response_payload, dict):
        data = response_payload
        if (
            "trip_title" in data
            and "destination" in data
            and "days" in data
            and isinstance(data["days"], list)
        ):
            trip_plan = data
    elif isinstance(response_payload, str):
        trip_plan = _parse_trip_plan(response_payload)

    now = datetime.now(UTC)
    title = envelope["triptitle"].strip()[:120]

    payload: dict[str, Any] = {
        "messages": history,
        "updated_at": now,
        "recommendations": envelope["recommendations"],
    }
    if envelope["triptitle"].strip():
        payload["trip_title"] = envelope["triptitle"].strip()[:120]
    payload["title"] = title

    conv_ref.set(payload, merge=True)

    # Increment daily analytics counter
    from google.cloud import firestore as fs

    db.collection("analytics").document("daily_usage").set(
        {"requests": fs.Increment(1)}, merge=True
    )

    return MessageOut(
        conversation_id=conv_ref.id,
        user_message=body.content,
        assistant_message=assistant_message,
        recommendations=envelope["recommendations"],
        trip_plan=trip_plan,
        created_at=now,
    )


@router.get("/conversations")
async def list_conversations(user: dict = Depends(get_current_user)):
    db = get_db()
    docs = (
        db.collection("users")
        .document(user["uid"])
        .collection("conversations")
        .order_by("updated_at", direction="DESCENDING")
        .limit(50)
        .stream()
    )
    return [{"id": d.id, **{k: v for k, v in d.to_dict().items() if k != "messages"}} for d in docs]


@router.get("/conversations/{conv_id}")
async def get_conversation(conv_id: str, user: dict = Depends(get_current_user)):
    db = get_db()
    doc = (
        db.collection("users")
        .document(user["uid"])
        .collection("conversations")
        .document(conv_id)
        .get()
    )
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return {"id": doc.id, **doc.to_dict()}


@router.patch("/conversations/{conv_id}")
async def update_conversation(
    conv_id: str, body: ConversationUpdateIn, user: dict = Depends(get_current_user)
):
    db = get_db()
    ref = db.collection("users").document(user["uid"]).collection("conversations").document(conv_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Conversation not found")

    ref.update({"title": body.title[:120], "updated_at": datetime.now(UTC)})
    updated = ref.get()
    return {"id": updated.id, **{k: v for k, v in updated.to_dict().items() if k != "messages"}}


@router.delete("/conversations/{conv_id}", status_code=204)
async def delete_conversation(conv_id: str, user: dict = Depends(get_current_user)):
    db = get_db()
    ref = db.collection("users").document(user["uid"]).collection("conversations").document(conv_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Conversation not found")
    ref.delete()
