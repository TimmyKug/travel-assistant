"""
AI chat router - wraps Gemini Flash with conversation persistence in Firestore.
"""

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from services.firestore_client import get_db
from services.gemini import chat as gemini_chat
from services.jwt_auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)


class MessageIn(BaseModel):
    conversation_id: str | None = None
    content: str


class MessageOut(BaseModel):
    conversation_id: str
    user_message: str
    assistant_message: str
    created_at: datetime


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

    history.append({"role": "user", "parts": [body.content]})
    logger.info("ai_chat_request", extra={"uid": uid, "conversation_id": conv_ref.id})
    reply = await gemini_chat(uid=uid, messages=history)
    history.append({"role": "model", "parts": [reply]})

    now = datetime.now(UTC)
    conv_ref.set(
        {
            "messages": history,
            "updated_at": now,
            "title": history[0]["parts"][0][:60] if len(history) == 2 else None,
        },
        merge=True,
    )

    # Increment daily analytics counter
    from google.cloud import firestore as fs

    db.collection("analytics").document("daily_usage").set(
        {"requests": fs.Increment(1)}, merge=True
    )

    return MessageOut(
        conversation_id=conv_ref.id,
        user_message=body.content,
        assistant_message=reply,
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
