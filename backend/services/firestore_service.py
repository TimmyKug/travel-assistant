from google.cloud import firestore
from functools import lru_cache
from datetime import datetime, timezone


@lru_cache
def get_db():
    return firestore.Client()  # Uses VM Service Account automatically


# ── Users ─────────────────────────────────────────────────────────────────────
def get_or_create_user(uid: str, email: str, display_name: str) -> dict:
    db = get_db()
    ref = db.collection("users").document(uid)
    doc = ref.get()
    if not doc.exists:
        data = {"email": email, "display_name": display_name, "created_at": now()}
        ref.set(data)
        return data
    return doc.to_dict()


# ── Conversations ─────────────────────────────────────────────────────────────
def save_message(uid: str, conv_id: str, role: str, content: str):
    db = get_db()
    (db.collection("users").document(uid)
     .collection("conversations").document(conv_id)
     .collection("messages").add({"role": role, "content": content, "timestamp": now()}))


def get_history(uid: str, conv_id: str, limit: int = 20) -> list[dict]:
    db = get_db()
    msgs = (db.collection("users").document(uid)
            .collection("conversations").document(conv_id)
            .collection("messages").order_by("timestamp").limit_to_last(limit).get())
    return [m.to_dict() for m in msgs]


def list_conversations(uid: str) -> list[dict]:
    db = get_db()
    docs = (db.collection("users").document(uid).collection("conversations")
            .order_by("updated_at", direction=firestore.Query.DESCENDING).limit(20).get())
    return [{"id": d.id, **d.to_dict()} for d in docs]


def upsert_conversation(uid: str, conv_id: str, title: str):
    db = get_db()
    (db.collection("users").document(uid)
     .collection("conversations").document(conv_id)
     .set({"title": title, "updated_at": now()}, merge=True))


# ── Trips ─────────────────────────────────────────────────────────────────────
def save_trip(uid: str, trip: dict) -> str:
    db = get_db()
    trip["created_at"] = now()
    _, ref = db.collection("users").document(uid).collection("trips").add(trip)
    return ref.id


def list_trips(uid: str) -> list[dict]:
    db = get_db()
    docs = (db.collection("users").document(uid).collection("trips")
            .order_by("created_at", direction=firestore.Query.DESCENDING).get())
    return [{"id": d.id, **d.to_dict()} for d in docs]


def delete_trip(uid: str, trip_id: str):
    db = get_db()
    db.collection("users").document(uid).collection("trips").document(trip_id).delete()


# ── Analytics ─────────────────────────────────────────────────────────────────
def log_event(event_type: str, uid: str, metadata: dict = {}):
    db = get_db()
    db.collection("analytics").add(
        {"type": event_type, "uid": uid, "metadata": metadata, "timestamp": now()}
    )


def now():
    return datetime.now(timezone.utc)
