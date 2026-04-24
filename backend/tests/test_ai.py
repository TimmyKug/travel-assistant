from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch


def _envelope(
    response,
    triptitle="Trip Title",
    recommendations=None,
):
    import json

    if recommendations is None:
        recommendations = ["Suggest flights", "Find hotels"]

    return json.dumps(
        {
            "triptitle": triptitle,
            "response": response,
            "recommendations": recommendations,
        }
    )


def test_chat_new_conversation(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-123"
    mock_conv_ref.get.return_value.exists = False
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    with patch(
        "routers.ai.gemini_chat",
        new=AsyncMock(
            return_value=_envelope(
                "Here are some travel tips!",
                triptitle="Starter Trip",
            )
        ),
    ):
        response = client.post("/api/ai/chat", json={"content": "Plan a trip to Rome"})

    assert response.status_code == 200
    data = response.json()
    assert data["conversation_id"] == "conv-123"
    assert data["user_message"] == "Plan a trip to Rome"
    assert data["assistant_message"] == "Here are some travel tips!"
    assert data["recommendations"] == ["Suggest flights", "Find hotels"]
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
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    with patch(
        "routers.ai.gemini_chat",
        new=AsyncMock(
            return_value=_envelope(
                "Great choice!",
                triptitle="Paris Idea",
            )
        ),
    ):
        response = client.post(
            "/api/ai/chat",
            json={"content": "What about Paris?", "conversation_id": "conv-456"},
        )

    assert response.status_code == 200
    assert response.json()["assistant_message"] == "Great choice!"
    assert response.json()["recommendations"] == ["Suggest flights", "Find hotels"]


def test_chat_trip_json_format_returns_trip_plan(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-json"
    mock_conv_ref.get.return_value.exists = False
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    with patch(
        "routers.ai.gemini_chat",
        new=AsyncMock(
            return_value=_envelope(
                {
                    "trip_title": "Rome Weekend",
                    "destination": "Rome",
                    "summary": "3 days",
                    "days": [
                        {
                            "day": 1,
                            "date": "2026-06-01",
                            "items": [
                                {
                                    "time": "09:00",
                                    "title": "Colosseum",
                                    "description": "Visit",
                                    "category": "activity",
                                    "estimated_cost": "20",
                                }
                            ],
                        }
                    ],
                    "hotels": [
                        {
                            "night": 1,
                            "date": "2026-06-01",
                            "options": [
                                {
                                    "name": "Budget Inn Rome",
                                    "area": "Centro",
                                    "nightly_estimate": "80 EUR",
                                    "reason": "Central and affordable",
                                }
                            ],
                        }
                    ],
                    "budget": {"currency": "EUR", "estimated_total": "450", "notes": "approx"},
                },
                triptitle="Rome Weekend",
            )
        ),
    ):
        response = client.post(
            "/api/ai/chat",
            json={"content": "Plan a trip to Rome"},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["trip_plan"] is not None
    assert data["trip_plan"]["destination"] == "Rome"
    assert data["recommendations"] == ["Suggest flights", "Find hotels"]
    stored = mock_conv_ref.set.call_args.args[0]
    assert stored["title"] == "Rome Weekend"


def test_chat_trip_json_format_invalid_json_returns_none(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-json-invalid"
    mock_conv_ref.get.return_value.exists = False
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    with patch(
        "routers.ai.gemini_chat",
        new=AsyncMock(
            return_value=_envelope(
                "Phase 1 questions before GO",
                triptitle="Budget Discovery",
            )
        ),
    ):
        response = client.post(
            "/api/ai/chat",
            json={"content": "Plan a trip"},
        )

    assert response.status_code == 200
    assert response.json()["trip_plan"] is None
    assert response.json()["recommendations"] == ["Suggest flights", "Find hotels"]


def test_chat_bootstrap_does_not_store_user_prompt(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-bootstrap"
    mock_conv_ref.get.return_value.exists = False
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    with patch(
        "routers.ai.gemini_chat",
        new=AsyncMock(
            return_value=_envelope(
                "Welcome message",
                triptitle="Welcome Trip",
            )
        ),
    ):
        response = client.post(
            "/api/ai/chat",
            json={
                "content": "Bootstrap prompt",
                "is_bootstrap": True,
            },
        )

    assert response.status_code == 200
    assert response.json()["assistant_message"] == "Welcome message"
    assert response.json()["recommendations"] == ["Suggest flights", "Find hotels"]
    mock_conv_ref.set.assert_called_once()
    stored = mock_conv_ref.set.call_args.args[0]
    assert stored["messages"] == [{"role": "model", "parts": ["Welcome message"]}]
    assert stored["title"] == "Welcome Trip"


def test_chat_invalid_envelope_returns_502(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_ref.id = "conv-bad-envelope"
    mock_conv_ref.get.return_value.exists = False
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    with patch("routers.ai.gemini_chat", new=AsyncMock(return_value='{"response":"hello"}')):
        response = client.post("/api/ai/chat", json={"content": "Hello"})

    assert response.status_code == 502
    assert "envelope contract violation" in response.json()["detail"].lower()


def test_chat_conversation_not_found(client, mock_db):
    mock_conv_ref = MagicMock()
    mock_conv_doc = MagicMock()
    mock_conv_doc.exists = False
    mock_conv_ref.get.return_value = mock_conv_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_conv_ref

    response = client.post(
        "/api/ai/chat",
        json={"content": "Hello", "conversation_id": "nonexistent"},
    )
    assert response.status_code == 404


def test_list_conversations(client, mock_db):
    mock_doc = MagicMock()
    mock_doc.id = "conv-123"
    mock_doc.to_dict.return_value = {
        "updated_at": datetime.now(UTC),
        "title": "Trip to Rome",
        "messages": [],
    }
    mock_db.collection.return_value.document.return_value.collection.return_value.order_by.return_value.limit.return_value.stream.return_value = [
        mock_doc
    ]

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
        "updated_at": datetime.now(UTC),
    }
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = mock_doc

    response = client.get("/api/ai/conversations/conv-123")
    assert response.status_code == 200
    assert response.json()["id"] == "conv-123"


def test_get_conversation_not_found(client, mock_db):
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = mock_doc

    response = client.get("/api/ai/conversations/nonexistent")
    assert response.status_code == 404


def test_update_conversation_found(client, mock_db):
    mock_ref = MagicMock()
    existing_doc = MagicMock()
    existing_doc.exists = True
    updated_doc = MagicMock()
    updated_doc.id = "conv-123"
    updated_doc.to_dict.return_value = {
        "title": "Summer in Lisbon",
        "updated_at": datetime.now(UTC),
        "messages": [],
    }
    mock_ref.get.side_effect = [existing_doc, updated_doc]
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.patch("/api/ai/conversations/conv-123", json={"title": "Summer in Lisbon"})
    assert response.status_code == 200
    assert response.json()["id"] == "conv-123"
    assert response.json()["title"] == "Summer in Lisbon"
    mock_ref.update.assert_called_once()


def test_update_conversation_not_found(client, mock_db):
    mock_ref = MagicMock()
    missing_doc = MagicMock()
    missing_doc.exists = False
    mock_ref.get.return_value = missing_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.patch("/api/ai/conversations/nonexistent", json={"title": "New title"})
    assert response.status_code == 404


def test_delete_conversation_found(client, mock_db):
    mock_ref = MagicMock()
    existing_doc = MagicMock()
    existing_doc.exists = True
    mock_ref.get.return_value = existing_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.delete("/api/ai/conversations/conv-123")
    assert response.status_code == 204
    mock_ref.delete.assert_called_once()


def test_delete_conversation_not_found(client, mock_db):
    mock_ref = MagicMock()
    missing_doc = MagicMock()
    missing_doc.exists = False
    mock_ref.get.return_value = missing_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.delete("/api/ai/conversations/nonexistent")
    assert response.status_code == 404
