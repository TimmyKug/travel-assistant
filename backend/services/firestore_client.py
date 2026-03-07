"""
Firestore client — single shared instance.
Collections:
  users/{uid}                         — user profiles
  users/{uid}/conversations/{id}      — chat history
  users/{uid}/trips/{id}              — saved itineraries
  analytics/daily_usage               — aggregated stats (not per-user)
  rate_limits/{uid}                   — Gemini API daily usage tracking
"""
import os
from google.cloud import firestore

_db: firestore.Client | None = None


def get_db() -> firestore.Client:
    global _db
    if _db is None:
        _db = firestore.Client(project=os.environ["GCP_PROJECT_ID"])
    return _db
