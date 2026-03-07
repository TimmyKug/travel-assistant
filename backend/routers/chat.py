from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from routers.auth import get_current_user
from services.firestore_client import get_db
from services.gemini import ask_gemini

router = APIRouter()


class ChatRequest(BaseModel):
    content: str
    session_id: str | None = None


@router.post("/")
async def chat(req: ChatRequest, user_id: str = Depends(get_current_user)):
    db = get_db()
    user_ref = db.collection("users").document(user_id)

    session_id = req.session_id
    if not session_id:
        session_ref = user_ref.collection("sessions").document()
        session_ref.set({
            "title": req.content[:60],
            "created_at": datetime.now(timezone.utc).isoformat(),
        })
        session_id = session_ref.id
    else:
        session_ref = user_ref.collection("sessions").document(session_id)
        if not session_ref.get().exists:
            raise HTTPException(status_code=404, detail="Session not found")

    messages_ref = session_ref.collection("messages")
    history = [
        {"role": m.to_dict()["role"], "content": m.to_dict()["content"]}
        for m in messages_ref.order_by("timestamp").stream()
    ]
    history.append({"role": "user", "content": req.content})

    reply = await ask_gemini(history)

    ts = datetime.now(timezone.utc).isoformat()
    messages_ref.add({"role": "user",  "content": req.content, "timestamp": ts})
    messages_ref.add({"role": "model", "content": reply,       "timestamp": ts})

    db.collection("analytics").add({
        "event": "chat_message",
        "user_id": user_id,
        "session_id": session_id,
        "timestamp": ts,
    })

    return {"reply": reply, "session_id": session_id}


@router.get("/sessions")
async def list_sessions(user_id: str = Depends(get_current_user)):
    db = get_db()
    sessions = (
        db.collection("users").document(user_id)
        .collection("sessions")
        .order_by("created_at", direction="DESCENDING")
        .limit(30).stream()
    )
    return [{"id": s.id, **s.to_dict()} for s in sessions]


@router.get("/sessions/{session_id}")
async def get_session(session_id: str, user_id: str = Depends(get_current_user)):
    db = get_db()
    messages = (
        db.collection("users").document(user_id)
        .collection("sessions").document(session_id)
        .collection("messages").order_by("timestamp").stream()
    )
    return [m.to_dict() for m in messages]


@router.delete("/sessions/{session_id}")
async def delete_session(session_id: str, user_id: str = Depends(get_current_user)):
    db = get_db()
    ref = db.collection("users").document(user_id).collection("sessions").document(session_id)
    for msg in ref.collection("messages").stream():
        msg.reference.delete()
    ref.delete()
    return {"deleted": session_id}
