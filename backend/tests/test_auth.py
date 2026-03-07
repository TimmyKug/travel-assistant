from unittest.mock import MagicMock


def test_upsert_user_creates_doc(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_ref

    response = client.post("/api/auth/me")
    assert response.status_code == 200
    data = response.json()
    assert data["uid"] == "test-uid"
    assert data["email"] == "test@example.com"
    mock_ref.set.assert_called_once()


def test_upsert_user_updates_existing(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_ref

    response = client.post("/api/auth/me")
    assert response.status_code == 200
    mock_ref.update.assert_called_once()
    mock_ref.set.assert_not_called()


def test_get_user_found(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "uid": "test-uid",
        "email": "test@example.com",
        "display_name": "Test User",
        "photo_url": "https://example.com/photo.jpg",
    }
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_ref

    response = client.get("/api/auth/me")
    assert response.status_code == 200
    assert response.json()["uid"] == "test-uid"


def test_get_user_creates_if_missing(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_ref

    response = client.get("/api/auth/me")
    assert response.status_code == 200
    assert response.json()["uid"] == "test-uid"
