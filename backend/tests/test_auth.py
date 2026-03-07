from unittest.mock import MagicMock, patch


def test_register_creates_user(client, mock_db):
    mock_db.collection.return_value.where.return_value.limit.return_value.stream.return_value = iter([])

    response = client.post("/api/auth/register", json={
        "name": "Alice", "email": "alice@example.com", "password": "password123"
    })
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Alice"
    assert "token" in data
    assert "user_id" in data
    mock_db.collection.return_value.document.return_value.set.assert_called_once()


def test_register_duplicate_email(client, mock_db):
    existing = MagicMock()
    mock_db.collection.return_value.where.return_value.limit.return_value.stream.return_value = iter([existing])

    response = client.post("/api/auth/register", json={
        "name": "Alice", "email": "alice@example.com", "password": "password123"
    })
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"]


def test_login_success(client, mock_db):
    from services.firebase_auth import hash_password
    user_doc = MagicMock()
    user_doc.to_dict.return_value = {
        "uid": "test-uid",
        "email": "alice@example.com",
        "display_name": "Alice",
        "password_hash": hash_password("password123"),
    }
    mock_db.collection.return_value.where.return_value.limit.return_value.stream.return_value = iter([user_doc])

    response = client.post("/api/auth/login", json={
        "email": "alice@example.com", "password": "password123"
    })
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Alice"
    assert "token" in data


def test_login_wrong_password(client, mock_db):
    from services.firebase_auth import hash_password
    user_doc = MagicMock()
    user_doc.to_dict.return_value = {
        "uid": "test-uid",
        "email": "alice@example.com",
        "display_name": "Alice",
        "password_hash": hash_password("correct-password"),
    }
    mock_db.collection.return_value.where.return_value.limit.return_value.stream.return_value = iter([user_doc])

    response = client.post("/api/auth/login", json={
        "email": "alice@example.com", "password": "wrong-password"
    })
    assert response.status_code == 401


def test_login_unknown_email(client, mock_db):
    mock_db.collection.return_value.where.return_value.limit.return_value.stream.return_value = iter([])

    response = client.post("/api/auth/login", json={
        "email": "nobody@example.com", "password": "password123"
    })
    assert response.status_code == 401


def test_get_me(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "uid": "test-uid",
        "email": "test@example.com",
        "display_name": "Test User",
    }
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_ref

    response = client.get("/api/auth/me")
    assert response.status_code == 200
    assert response.json()["uid"] == "test-uid"


def test_get_me_not_found(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_ref

    response = client.get("/api/auth/me")
    assert response.status_code == 404
