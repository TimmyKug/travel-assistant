def test_health(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_db_health_healthy(client, mock_db):
    user_doc = _doc(
        True, {"display_name": "Sentinel User", "email": "sentinel@example.com"}
    )
    trip_doc = _doc(
        True,
        {
            "destination": "Rome",
            "start_date": "2026-06-01",
            "end_date": "2026-06-07",
            "status": "planned",
        },
    )
    analytics_doc = _doc(True, {"seed_version": 1, "last_seeded_at": "2026-04-09T12:00:00Z"})
    _configure_health_mocks(mock_db, user_doc, trip_doc, analytics_doc)

    response = client.get("/api/health/db")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "checked_documents": 3}


def test_db_health_missing_reference_data(client, mock_db):
    user_doc = _doc(True, {"display_name": "Sentinel User"})
    trip_doc = _doc(False)
    analytics_doc = _doc(True, {"seed_version": 1})
    _configure_health_mocks(mock_db, user_doc, trip_doc, analytics_doc)

    response = client.get("/api/health/db")

    assert response.status_code == 500
    assert response.json() == {
        "status": "unhealthy",
        "reason": "integrity_error",
        "errors": [
            "users/sentinel-user missing field: email",
            "users/sentinel-user/trips/sentinel-trip missing",
            "analytics/system missing field: last_seeded_at",
        ],
        "checked_documents": 3,
    }


def test_db_health_connectivity_error(client, mock_db):
    mock_db.collection.side_effect = RuntimeError("firestore unavailable")

    response = client.get("/api/health/db")

    assert response.status_code == 500
    assert response.json() == {
        "status": "unhealthy",
        "reason": "connectivity_error",
        "errors": ["firestore unavailable"],
    }


def _doc(exists, data=None):
    from unittest.mock import MagicMock

    doc = MagicMock()
    doc.exists = exists
    doc.to_dict.return_value = data
    return doc


def _configure_health_mocks(mock_db, user_doc, trip_doc, analytics_doc):
    from unittest.mock import MagicMock

    users_collection = MagicMock()
    analytics_collection = MagicMock()

    user_ref = users_collection.document.return_value
    trip_collection = user_ref.collection.return_value
    trip_ref = trip_collection.document.return_value
    analytics_ref = analytics_collection.document.return_value

    def collection_side_effect(name):
        if name == "users":
            return users_collection
        if name == "analytics":
            return analytics_collection
        raise AssertionError(f"Unexpected collection: {name}")

    def document_side_effect(doc_id):
        if doc_id == "sentinel-user":
            return user_ref
        if doc_id == "system":
            return analytics_ref
        raise AssertionError(f"Unexpected document: {doc_id}")

    def trip_document_side_effect(doc_id):
        if doc_id == "sentinel-trip":
            return trip_ref
        raise AssertionError(f"Unexpected trip document: {doc_id}")

    mock_db.collection.side_effect = collection_side_effect
    users_collection.document.side_effect = document_side_effect
    analytics_collection.document.side_effect = document_side_effect
    trip_collection.document.side_effect = trip_document_side_effect
    user_ref.get.return_value = user_doc
    trip_ref.get.return_value = trip_doc
    analytics_ref.get.return_value = analytics_doc
