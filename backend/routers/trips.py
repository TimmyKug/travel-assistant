"""
Trips router — CRUD for saved travel itineraries.
"""

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from metrics import trips_operations_total
from services.firestore_client import get_db
from services.jwt_auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)


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
    db = get_db()
    docs = (
        db.collection("users")
        .document(user["uid"])
        .collection("trips")
        .order_by("updated_at", direction="DESCENDING")
        .limit(100)
        .stream()
    )
    return [TripOut(id=d.id, **d.to_dict()) for d in docs]


@router.post("/", response_model=TripOut)
async def create_trip(body: TripIn, user: dict = Depends(get_current_user)):
    db = get_db()
    now = datetime.now(UTC)
    ref = db.collection("users").document(user["uid"]).collection("trips").document()
    data = {**body.model_dump(), "created_at": now, "updated_at": now}
    ref.set(data)
    trips_operations_total.labels(operation="create").inc()
    logger.info("trip_created", extra={"uid": user["uid"], "trip_id": ref.id})
    return TripOut(id=ref.id, **data)


@router.put("/{trip_id}", response_model=TripOut)
async def update_trip(trip_id: str, body: TripIn, user: dict = Depends(get_current_user)):
    db = get_db()
    ref = db.collection("users").document(user["uid"]).collection("trips").document(trip_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Trip not found")
    now = datetime.now(UTC)
    data = {**body.model_dump(), "updated_at": now}
    ref.update(data)
    trips_operations_total.labels(operation="update").inc()
    logger.info("trip_updated", extra={"uid": user["uid"], "trip_id": trip_id})
    return TripOut(id=trip_id, **{**doc.to_dict(), **data})


@router.delete("/{trip_id}", status_code=204)
async def delete_trip(trip_id: str, user: dict = Depends(get_current_user)):
    db = get_db()
    ref = db.collection("users").document(user["uid"]).collection("trips").document(trip_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Trip not found")
    ref.delete()
    trips_operations_total.labels(operation="delete").inc()
    logger.info("trip_deleted", extra={"uid": user["uid"], "trip_id": trip_id})
