"""
Auth router — creates/fetches user profile in Firestore on first sign-in.
The actual authentication is handled by Firebase on the frontend;
this endpoint just ensures a Firestore user doc exists.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from services.firebase_auth import get_current_user
from services.firestore_client import get_db

router = APIRouter()


class UserProfile(BaseModel):
    uid: str
    email: str | None
    display_name: str | None
    photo_url: str | None


@router.post("/me", response_model=UserProfile)
async def upsert_user(user: dict = Depends(get_current_user)):
    """Called by frontend after login — creates user doc if it doesn't exist."""
    db = get_db()
    uid = user["uid"]
    ref = db.collection("users").document(uid)

    profile = {
        "uid": uid,
        "email": user.get("email"),
        "display_name": user.get("name"),
        "photo_url": user.get("picture"),
    }

    doc = ref.get()
    if not doc.exists:
        ref.set({**profile, "created_at": __import__("datetime").datetime.utcnow()})
    else:
        ref.update({"email": profile["email"], "display_name": profile["display_name"]})

    return UserProfile(**profile)


@router.get("/me", response_model=UserProfile)
async def get_user(user: dict = Depends(get_current_user)):
    db = get_db()
    doc = db.collection("users").document(user["uid"]).get()
    if not doc.exists:
        return await upsert_user(user)
    data = doc.to_dict()
    return UserProfile(**data)
