"""
Test configuration — sets required env vars and stubs heavy dependencies
before any app import so module-level initialisations don't fail.
"""
import os
import sys
from unittest.mock import MagicMock

import pytest

# ── Env vars required before app import ──────────────────────────────────────
os.environ.setdefault("GCP_PROJECT_ID", "test-project")
os.environ.setdefault("GEMINI_API_KEY", "fake-gemini-key")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-tests-only")

# ── Stub out google.generativeai before it is imported ───────────────────────
_mock_genai = MagicMock()
sys.modules["google.generativeai"] = _mock_genai

# ── Fixtures ─────────────────────────────────────────────────────────────────

TEST_USER = {
    "uid": "test-uid",
    "email": "test@example.com",
    "name": "Test User",
}


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def client(mock_db):
    from fastapi.testclient import TestClient
    from main import app
    from services.firebase_auth import get_current_user
    import services.firestore_client as _fc

    app.dependency_overrides[get_current_user] = lambda: TEST_USER
    # get_db() is called directly (not via Depends), so inject into the
    # module-level cache so the lazy initialisation never runs.
    _fc._db = mock_db

    with TestClient(app) as c:
        yield c

    _fc._db = None
    app.dependency_overrides.clear()
