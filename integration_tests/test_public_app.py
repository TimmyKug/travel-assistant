import json
import os
from pathlib import Path

import httpx
from google.cloud import firestore


STATE_FILE = Path(os.environ.get("INTEGRATION_STATE_FILE", ".integration-test-state.json"))
TEST_RUN_ID = os.environ["TEST_RUN_ID"]
TEST_EMAIL = os.environ.get("TEST_EMAIL", f"integration-{TEST_RUN_ID}@example.com")
TEST_PASSWORD = os.environ.get("TEST_PASSWORD", f"integration-{TEST_RUN_ID}-password")


def _app_url() -> str:
    return os.environ["APP_URL"].rstrip("/")


def _write_state(**updates):
    state = {}
    if STATE_FILE.exists():
        state = json.loads(STATE_FILE.read_text())
    state.update(updates)
    STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True))


def _cleanup_firestore_user(user_id: str | None, email: str):
    db = firestore.Client(project=os.environ["GCP_PROJECT_ID"])
    refs = []

    if user_id:
        refs.append(db.collection("users").document(user_id))

    for doc in db.collection("users").where("email", "==", email).stream():
        if all(doc.reference.path != ref.path for ref in refs):
            refs.append(doc.reference)

    for ref in refs:
        _delete_document_tree(ref)


def _delete_document_tree(doc_ref):
    for collection in doc_ref.collections():
        _delete_collection(collection)
    doc_ref.delete()


def _delete_collection(collection_ref, batch_size=50):
    while True:
        docs = list(collection_ref.limit(batch_size).stream())
        if not docs:
            break
        for doc in docs:
            _delete_document_tree(doc.reference)


def test_public_health():
    with httpx.Client(timeout=20) as client:
        response = client.get(f"{_app_url()}/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_firestore_integrity_health():
    with httpx.Client(timeout=20) as client:
        response = client.get(f"{_app_url()}/api/health/db")

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_auth_and_trip_crud_leave_no_data():
    user_id = None
    trip_id = None
    _write_state(email=TEST_EMAIL)

    try:
        with httpx.Client(timeout=30) as client:
            register = client.post(
                f"{_app_url()}/api/auth/register",
                json={
                    "name": "Integration Test User",
                    "email": TEST_EMAIL,
                    "password": TEST_PASSWORD,
                },
            )
            assert register.status_code == 200, register.text
            register_data = register.json()
            user_id = register_data["user_id"]
            _write_state(user_id=user_id, email=TEST_EMAIL)

            login = client.post(
                f"{_app_url()}/api/auth/login",
                json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
            )
            assert login.status_code == 200, login.text
            token = login.json()["token"]
            headers = {"Authorization": f"Bearer {token}"}

            me = client.get(f"{_app_url()}/api/auth/me", headers=headers)
            assert me.status_code == 200, me.text
            assert me.json()["email"] == TEST_EMAIL

            trip_body = {
                "title": "Integration Test Trip",
                "destination": "Berlin",
                "start_date": "2026-06-01",
                "end_date": "2026-06-03",
                "notes": f"created by integration test {TEST_RUN_ID}",
                "itinerary": [],
            }
            created = client.post(f"{_app_url()}/api/trips/", json=trip_body, headers=headers)
            assert created.status_code == 200, created.text
            trip_id = created.json()["id"]
            _write_state(user_id=user_id, email=TEST_EMAIL, trip_id=trip_id)

            listed = client.get(f"{_app_url()}/api/trips/", headers=headers)
            assert listed.status_code == 200, listed.text
            assert any(trip["id"] == trip_id for trip in listed.json())

            updated_body = {**trip_body, "title": "Updated Integration Test Trip"}
            updated = client.put(
                f"{_app_url()}/api/trips/{trip_id}",
                json=updated_body,
                headers=headers,
            )
            assert updated.status_code == 200, updated.text
            assert updated.json()["title"] == "Updated Integration Test Trip"

            deleted = client.delete(f"{_app_url()}/api/trips/{trip_id}", headers=headers)
            assert deleted.status_code == 204, deleted.text
            trip_id = None
            _write_state(user_id=user_id, email=TEST_EMAIL, trip_id=None)

            listed_after_delete = client.get(f"{_app_url()}/api/trips/", headers=headers)
            assert listed_after_delete.status_code == 200, listed_after_delete.text
            assert all(trip["id"] != created.json()["id"] for trip in listed_after_delete.json())
    finally:
        _cleanup_firestore_user(user_id, TEST_EMAIL)
        _write_state(user_id=user_id, email=TEST_EMAIL, cleanup_attempted=True)


def test_backup_and_config_buckets_exist():
    from google.cloud import storage

    project_id = os.environ["GCP_PROJECT_ID"]
    storage_client = storage.Client(project=project_id)

    for bucket_name in (
        f"{project_id}-firestore-backups",
        f"{project_id}-travel-assistant-configs",
    ):
        bucket = storage_client.bucket(bucket_name)
        assert bucket.exists(), f"Expected bucket {bucket_name} to exist"
