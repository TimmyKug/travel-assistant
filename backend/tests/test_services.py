from datetime import date
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials

import services.firestore_client as firestore_client
import services.gemini as gemini
import services.jwt_auth as jwt_auth


@pytest.mark.asyncio
async def test_check_and_increment_rate_limit_initializes_counter(monkeypatch):
    today = date.today().isoformat()
    tx = MagicMock()
    snapshot = MagicMock()
    snapshot.exists = False
    snapshot.to_dict.return_value = {}
    ref = MagicMock()
    ref.get.return_value = snapshot
    db = MagicMock()
    db.collection.return_value.document.return_value = ref
    db.transaction.return_value = tx

    monkeypatch.setattr(gemini, "get_db", lambda: db)
    monkeypatch.setattr(gemini.firestore, "transactional", lambda fn: fn)

    count = await gemini.check_and_increment_rate_limit("user-1")

    assert count == 1
    tx.set.assert_called_once_with(ref, {"date": today, "count": 1})


@pytest.mark.asyncio
async def test_check_and_increment_rate_limit_raises_when_daily_limit_exceeded(monkeypatch):
    today = date.today().isoformat()
    snapshot = MagicMock()
    snapshot.exists = True
    snapshot.to_dict.return_value = {"date": today, "count": gemini.DAILY_LIMIT}
    ref = MagicMock()
    ref.get.return_value = snapshot
    db = MagicMock()
    db.collection.return_value.document.return_value = ref
    db.transaction.return_value = MagicMock()

    monkeypatch.setattr(gemini, "get_db", lambda: db)
    monkeypatch.setattr(gemini.firestore, "transactional", lambda fn: fn)

    with pytest.raises(HTTPException) as exc:
        await gemini.check_and_increment_rate_limit("user-1")

    assert exc.value.status_code == status.HTTP_429_TOO_MANY_REQUESTS


@pytest.mark.asyncio
async def test_gemini_chat_success(monkeypatch):
    monkeypatch.setattr(gemini, "check_and_increment_rate_limit", AsyncMock(return_value=1))
    mock_counter = MagicMock()
    monkeypatch.setattr(gemini, "ai_requests_total", mock_counter)
    monkeypatch.setattr(gemini, "gemini_duration_seconds", MagicMock())

    session = MagicMock()
    session.send_message.return_value.text = "hello from gemini"
    model = MagicMock()
    model.start_chat.return_value = session
    monkeypatch.setattr(gemini, "_model", model)

    result = await gemini.chat(
        uid="user-1",
        messages=[{"role": "user", "parts": ["Hi there"]}],
        response_format="trip_json",
    )

    assert result == "hello from gemini"
    model.start_chat.assert_called_once_with(history=[])
    session.send_message.assert_called_once_with("Hi there")
    mock_counter.labels.assert_called_with(status="success")


@pytest.mark.asyncio
async def test_gemini_chat_rate_limited_path(monkeypatch):
    monkeypatch.setattr(
        gemini,
        "check_and_increment_rate_limit",
        AsyncMock(
            side_effect=HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="limit hit",
            )
        ),
    )
    mock_counter = MagicMock()
    monkeypatch.setattr(gemini, "ai_requests_total", mock_counter)

    with pytest.raises(HTTPException) as exc:
        await gemini.chat(uid="user-1", messages=[{"role": "user", "parts": ["Hi"]}])

    assert exc.value.status_code == status.HTTP_429_TOO_MANY_REQUESTS
    mock_counter.labels.assert_called_with(status="rate_limited")


@pytest.mark.asyncio
async def test_gemini_chat_error_path(monkeypatch):
    monkeypatch.setattr(gemini, "check_and_increment_rate_limit", AsyncMock(return_value=1))
    mock_counter = MagicMock()
    monkeypatch.setattr(gemini, "ai_requests_total", mock_counter)
    monkeypatch.setattr(gemini, "gemini_duration_seconds", MagicMock())

    session = MagicMock()
    session.send_message.side_effect = RuntimeError("boom")
    model = MagicMock()
    model.start_chat.return_value = session
    monkeypatch.setattr(gemini, "_model", model)

    with pytest.raises(RuntimeError, match="boom"):
        await gemini.chat(uid="user-1", messages=[{"role": "user", "parts": ["Hi"]}])

    mock_counter.labels.assert_called_with(status="error")


@pytest.mark.asyncio
async def test_get_current_user_success():
    token = jwt_auth.create_access_token(uid="uid-123", email="me@example.com", name="Me")
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)

    user = await jwt_auth.get_current_user(creds)

    assert user["uid"] == "uid-123"
    assert user["email"] == "me@example.com"
    assert user["name"] == "Me"


@pytest.mark.asyncio
async def test_get_current_user_invalid_token_raises_401():
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="invalid.token")

    with pytest.raises(HTTPException) as exc:
        await jwt_auth.get_current_user(creds)

    assert exc.value.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Invalid or expired token" in exc.value.detail


def test_password_hash_and_verify_roundtrip():
    hashed = jwt_auth.hash_password("secret-123")

    assert jwt_auth.verify_password("secret-123", hashed) is True
    assert jwt_auth.verify_password("wrong-password", hashed) is False


def test_firestore_client_get_db_caches_instance(monkeypatch):
    firestore_client._db = None
    fake_client = object()
    factory = MagicMock(return_value=fake_client)
    monkeypatch.setenv("GCP_PROJECT_ID", "project-for-tests")
    monkeypatch.setattr(firestore_client.firestore, "Client", factory)

    first = firestore_client.get_db()
    second = firestore_client.get_db()

    assert first is fake_client
    assert second is fake_client
    factory.assert_called_once_with(project="project-for-tests")
    firestore_client._db = None
