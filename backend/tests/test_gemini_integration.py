"""
Gemini integration tests (opt-in).

These tests call the real Gemini API and are skipped unless explicitly enabled.
Enable with:
  RUN_GEMINI_INTEGRATION=1 pytest tests/test_gemini_integration.py -m integration -v
"""

import json
import os

import pytest

from services import gemini as gemini_service


def _integration_enabled() -> bool:
    return os.getenv("RUN_GEMINI_INTEGRATION") == "1"


pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        not _integration_enabled(),
        reason="Set RUN_GEMINI_INTEGRATION=1 to run real Gemini integration tests.",
    ),
]


@pytest.fixture(autouse=True)
def _bypass_firestore_rate_limit(monkeypatch: pytest.MonkeyPatch):
    """
    Keep integration scope focused on Gemini responses.
    Firestore availability/credentials should not gate these tests.
    """

    async def _noop_rate_limit(_uid: str) -> int:
        return 1

    monkeypatch.setattr(gemini_service, "check_and_increment_rate_limit", _noop_rate_limit)


@pytest.mark.asyncio
async def test_gemini_phase1_responds() -> None:
    """Phase 1: model should respond with preference-elicitation text."""
    messages = [
        {
            "role": "user",
            "parts": [
                "I want a budget trip in Southeast Asia for 4 days. "
                "Start by asking me preference questions first."
            ],
        }
    ]

    reply = await gemini_service.chat(
        uid="gemini-integration-phase1",
        messages=messages,
        response_format="trip_json",
    )

    assert isinstance(reply, str)
    assert reply.strip() != ""


@pytest.mark.asyncio
async def test_gemini_phase2_returns_exact_trip_json_shape() -> None:
    """
    Phase 2: after GO, Gemini must return valid JSON with the required top-level keys.
    """
    messages = [
        {
            "role": "user",
            "parts": [
                "Destination: Hanoi. Duration: 3 days. Budget: low. "
                "Traveler type: solo. Interests: food + culture."
            ],
        },
        {
            "role": "model",
            "parts": ["Great. I have enough information. Type GO when you want the itinerary."],
        },
        {"role": "user", "parts": ["GO"]},
    ]

    reply = await gemini_service.chat(
        uid="gemini-integration-phase2",
        messages=messages,
        response_format="trip_json",
    )

    envelope = json.loads(reply)
    assert set(envelope.keys()) == {
        "triptitle",
        "response",
        "recommendations",
    }
    assert isinstance(envelope["triptitle"], str) and envelope["triptitle"].strip()
    assert isinstance(envelope["recommendations"], list)
    assert 2 <= len(envelope["recommendations"]) <= 4
    assert all(isinstance(item, str) and item.strip() for item in envelope["recommendations"])

    payload = envelope["response"]
    assert isinstance(payload, dict)

    expected_plan_keys = {"trip_title", "destination", "summary", "hotels", "days", "budget"}
    assert set(payload.keys()) == expected_plan_keys
    assert isinstance(payload["trip_title"], str) and payload["trip_title"].strip()
    assert isinstance(payload["destination"], str) and payload["destination"].strip()
    assert isinstance(payload["summary"], str)

    assert isinstance(payload["hotels"], list) and len(payload["hotels"]) >= 1
    for hotel_night in payload["hotels"]:
        assert {"night", "options"}.issubset(hotel_night.keys())
        assert isinstance(hotel_night["night"], int)
        if "date" in hotel_night:
            assert isinstance(hotel_night["date"], str)
        assert isinstance(hotel_night["options"], list) and len(hotel_night["options"]) >= 1
        for hotel in hotel_night["options"]:
            assert set(hotel.keys()) == {"name", "area", "nightly_estimate", "reason"}
            assert isinstance(hotel["name"], str) and hotel["name"].strip()

    assert isinstance(payload["days"], list) and len(payload["days"]) >= 1
    for day in payload["days"]:
        assert {"day", "date", "items"}.issubset(day.keys())
        assert isinstance(day["day"], int)
        assert isinstance(day["items"], list)
        for item in day["items"]:
            assert set(item.keys()) == {
                "time",
                "title",
                "description",
                "category",
                "estimated_cost",
            }
            assert item["category"] in {"transport", "activity", "food", "hotel", "note"}

    assert set(payload["budget"].keys()) == {"currency", "estimated_total", "notes"}
    assert isinstance(payload["budget"]["currency"], str) and payload["budget"]["currency"].strip()
    assert isinstance(payload["budget"]["estimated_total"], str)
