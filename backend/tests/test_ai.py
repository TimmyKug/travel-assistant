from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch


def test_chat_new_conversation(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-123"
    mock_conv_ref.get.return_value.exists = False
    mock_db.collection.return_value \
        .document.return_value \
        .collection.return_value \
        .document.return_value = mock_conv_ref

    with patch("routers.ai.gemini_chat", new=AsyncMock(return_value="Here are some travel tips!")):
        response = client.post("/api/ai/chat", json={"content": "Plan a trip to Rome"})

    assert response.status_code == 200
    data = response.json()
    assert data["conversation_id"] == "conv-123"
    assert data["user_message"] == "Plan a trip to Rome"
    assert data["assistant_message"] == "Here are some travel tips!"
    mock_conv_ref.set.assert_called_once()


def test_chat_existing_conversation(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-456"
    mock_conv_doc = MagicMock()
    mock_conv_doc.exists = True
    mock_conv_doc.to_dict.return_value = {
        "messages": [
            {"role": "user", "parts": ["Hello"]},
            {"role": "model", "parts": ["Hi! How can I help?"]},
        ]
    }
    mock_conv_ref.get.return_value = mock_conv_doc
    mock_db.collection.return_value \
        .document.return_value \
        .collection.return_value \
        .document.return_value = mock_conv_ref

    with patch("routers.ai.gemini_chat", new=AsyncMock(return_value="Great choice!")):
        response = client.post(
            "/api/ai/chat",
            json={"content": "What about Paris?", "conversation_id": "conv-456"},
        )

    assert response.status_code == 200
    assert response.json()["assistant_message"] == "Great choice!"


def test_chat_conversation_not_found(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_doc = MagicMock()
    mock_conv_doc.exists = False
    mock_conv_ref.get.return_value = mock_conv_doc
    mock_db.collection.return_value \
        .document.return_value \
        .collection.return_value \
        .document.return_value = mock_conv_ref

    response = client.post(
        "/api/ai/chat",
        json={"content": "Hello", "conversation_id": "nonexistent"},
    )
    assert response.status_code == 404


def test_list_conversations(client, mock_db):
    mock_doc = MagicMock()
    mock_doc.id = "conv-123"
    mock_doc.to_dict.return_value = {
        "updated_at": datetime.now(timezone.utc),
        "title": "Trip to Rome",
        "messages": [],
    }
    mock_db.collection.return_value \
        .document.return_value \
        .collection.return_value \
        .order_by.return_value \
        .limit.return_value \
        .stream.return_value = [mock_doc]

    response = client.get("/api/ai/conversations")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["id"] == "conv-123"
    assert "messages" not in data[0]


def test_get_conversation_found(client, mock_db):
    mock_doc = MagicMock()
    mock_doc.id = "conv-123"
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "messages": [{"role": "user", "parts": ["Hello"]}],
        "title": "Trip to Rome",
        "updated_at": datetime.now(timezone.utc),
    }
    mock_db.collection.return_value \
        .document.return_value \
        .collection.return_value \
        .document.return_value \
        .get.return_value = mock_doc

    response = client.get("/api/ai/conversations/conv-123")
    assert response.status_code == 200
    assert response.json()["id"] == "conv-123"


def test_get_conversation_not_found(client, mock_db):
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_db.collection.return_value \
        .document.return_value \
        .collection.return_value \
        .document.return_value \
        .get.return_value = mock_doc

    response = client.get("/api/ai/conversations/nonexistent")
    assert response.status_code == 404
