"""
Test configuration — patches firebase_admin before any app import so the
module-level initialisation in services/firebase_auth.py doesn't fail.
"""
import os
import sys
from unittest.mock import MagicMock

import pytest

# ── Env vars required before app import ──────────────────────────────────────
os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", "/fake/credentials.json")
os.environ.setdefault("GCP_PROJECT_ID", "test-project")

# ── Stub out firebase_admin before it is imported ────────────────────────────
_mock_firebase = MagicMock()
sys.modules["firebase_admin"] = _mock_firebase
sys.modules["firebase_admin.auth"] = _mock_firebase.auth
sys.modules["firebase_admin.credentials"] = _mock_firebase.credentials

# ── Fixtures ─────────────────────────────────────────────────────────────────

TEST_USER = {
    "uid": "test-uid",
    "email": "test@example.com",
    "name": "Test User",
    "picture": "https://example.com/photo.jpg",
}


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def client(mock_db):
    from fastapi.testclient import TestClient
    from main import app
    from services.firebase_auth import get_current_user
    from services.firestore_client import get_db

    app.dependency_overrides[get_current_user] = lambda: TEST_USER
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()
