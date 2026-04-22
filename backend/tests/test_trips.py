from datetime import UTC, datetime
from unittest.mock import MagicMock

TRIP_BODY = {
    "title": "Paris Trip",
    "destination": "Paris",
    "start_date": "2026-06-01",
    "end_date": "2026-06-10",
    "notes": "Book hotels",
    "itinerary": [],
}

NOW = datetime.now(UTC)


def _make_trip_doc(trip_id="trip-123"):
    doc = MagicMock()
    doc.id = trip_id
    doc.to_dict.return_value = {
        **TRIP_BODY,
        "created_at": NOW,
        "updated_at": NOW,
    }
    return doc


def test_list_trips(client, mock_db):
    mock_db.collection.return_value.document.return_value.collection.return_value.order_by.return_value.limit.return_value.stream.return_value = [
        _make_trip_doc()
    ]

    response = client.get("/api/trips/")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["title"] == "Paris Trip"
    assert data[0]["id"] == "trip-123"


def test_list_trips_empty(client, mock_db):
    mock_db.collection.return_value.document.return_value.collection.return_value.order_by.return_value.limit.return_value.stream.return_value = []

    response = client.get("/api/trips/")
    assert response.status_code == 200
    assert response.json() == []


def test_create_trip(client, mock_db):
    mock_ref = MagicMock()
    mock_ref.id = "new-trip-id"
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.post("/api/trips/", json=TRIP_BODY)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "new-trip-id"
    assert data["title"] == "Paris Trip"
    mock_ref.set.assert_called_once()


def test_update_trip_found(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {**TRIP_BODY, "created_at": NOW, "updated_at": NOW}
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.put("/api/trips/trip-123", json={**TRIP_BODY, "title": "Updated"})
    assert response.status_code == 200
    assert response.json()["title"] == "Updated"
    mock_ref.update.assert_called_once()


def test_update_trip_not_found(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.put("/api/trips/nonexistent", json=TRIP_BODY)
    assert response.status_code == 404


def test_delete_trip_found(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.delete("/api/trips/trip-123")
    assert response.status_code == 204
    mock_ref.delete.assert_called_once()


def test_delete_trip_not_found(client, mock_db):
    mock_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = mock_ref

    response = client.delete("/api/trips/nonexistent")
    assert response.status_code == 404
