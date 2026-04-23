"""
Health and Firestore integrity checks.
"""

import logging

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from services.firestore_client import get_db

router = APIRouter()
logger = logging.getLogger(__name__)

SENTINEL_USER_ID = "sentinel-user"
SENTINEL_TRIP_ID = "sentinel-trip"


def _require_fields(doc_dict: dict | None, required_fields: list[str], label: str) -> list[str]:
    if not doc_dict:
        return [f"{label} has no readable data"]

    missing = [field for field in required_fields if field not in doc_dict]
    return [f"{label} missing field: {field}" for field in missing]


@router.get("/health/db")
async def db_health():
    """
    Verifies that fixed sentinel documents exist and contain
    the minimum fields required for integrity monitoring.
    """
    db = get_db()
    errors: list[str] = []

    try:
        user_ref = db.collection("users").document(SENTINEL_USER_ID)
        trip_ref = user_ref.collection("trips").document(SENTINEL_TRIP_ID)
        analytics_ref = db.collection("analytics").document("system")

        user_doc = user_ref.get()
        trip_doc = trip_ref.get()
        analytics_doc = analytics_ref.get()
    except Exception as exc:  # pragma: no cover - defensive branch for live outages
        logger.exception(
            "db_integrity_check_unreachable",
            extra={
                "event": "db_connectivity_error",
                "reason": "connectivity_error",
            },
        )
        return JSONResponse(
            status_code=500,
            content={
                "status": "unhealthy",
                "reason": "connectivity_error",
                "errors": [str(exc)],
            },
        )

    if not user_doc.exists:
        errors.append("users/sentinel-user missing")
    else:
        errors.extend(
            _require_fields(
                user_doc.to_dict(),
                ["display_name", "email"],
                "users/sentinel-user",
            )
        )

    if not trip_doc.exists:
        errors.append("users/sentinel-user/trips/sentinel-trip missing")
    else:
        errors.extend(
            _require_fields(
                trip_doc.to_dict(),
                ["destination", "start_date", "end_date", "status"],
                "users/sentinel-user/trips/sentinel-trip",
            )
        )

    if not analytics_doc.exists:
        errors.append("analytics/system missing")
    else:
        errors.extend(
            _require_fields(
                analytics_doc.to_dict(),
                ["seed_version", "last_seeded_at"],
                "analytics/system",
            )
        )

    if errors:
        logger.error(
            "db_integrity_check_failed",
            extra={
                "event": "db_integrity_error",
                "reason": "integrity_error",
                "errors": errors,
                "sentinel_user_id": SENTINEL_USER_ID,
                "sentinel_trip_id": SENTINEL_TRIP_ID,
            },
        )
        return JSONResponse(
            status_code=500,
            content={
                "status": "unhealthy",
                "reason": "integrity_error",
                "errors": errors,
                "checked_documents": 3,
            },
        )

    return {
        "status": "healthy",
        "checked_documents": 3,
    }
