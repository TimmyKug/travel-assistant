"""
Trips router — CRUD for saved travel itineraries.
"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from services.firebase_auth import get_current_user
from services.firestore_client import get_db

router = APIRouter()


class TripIn(BaseModel):
    title: str
    destination: str
    start_date: str | None = None
    end_date: str | None = None
    notes: str | None = None
    itinerary: list[dict] = []
    conversation_id: str | None = None


class TripOut(TripIn):
    id: str
    created_at: datetime
    updated_at: datetime


@router.get("/", response_model=list[TripOut])
async def list_trips(user: dict = Depends(get_current_user)):
    db   = get_db()
    docs = db.collection("users").document(user["uid"]) \
             .collection("trips") \
             .order_by("updated_at", direction="DESCENDING") \
             .limit(100).stream()
    return [TripOut(id=d.id, **d.to_dict()) for d in docs]


@router.post("/", response_model=TripOut)
async def create_trip(body: TripIn, user: dict = Depends(get_current_user)):
    db  = get_db()
    now = datetime.now(timezone.utc)
    ref = db.collection("users").document(user["uid"]).collection("trips").document()
    data = {**body.model_dump(), "created_at": now, "updated_at": now}
    ref.set(data)
    return TripOut(id=ref.id, **data)


@router.put("/{trip_id}", response_model=TripOut)
async def update_trip(trip_id: str, body: TripIn, user: dict = Depends(get_current_user)):
    db  = get_db()
    ref = db.collection("users").document(user["uid"]).collection("trips").document(trip_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Trip not found")
    now  = datetime.now(timezone.utc)
    data = {**body.model_dump(), "updated_at": now}
    ref.update(data)
    return TripOut(id=trip_id, **{**doc.to_dict(), **data})


@router.delete("/{trip_id}", status_code=204)
async def delete_trip(trip_id: str, user: dict = Depends(get_current_user)):
    db  = get_db()
    ref = db.collection("users").document(user["uid"]).collection("trips").document(trip_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Trip not found")
    ref.delete()
