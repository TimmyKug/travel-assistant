"""
Gemini integration tests.

These tests call the real Gemini API.
"""

import json

import pytest

from services import gemini as gemini_service

pytestmark = [pytest.mark.integration]


def _step(label: str) -> None:
    # Printed in test logs to make failing stage obvious in CI output.
    print(f"[gemini-integration] {label}")


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
    _step("phase1: build prompt")
    messages = [
        {
            "role": "user",
            "parts": [
                "I want a budget trip in Southeast Asia for 4 days. "
                "Start by asking me preference questions first."
            ],
        }
    ]

    _step("phase1: call gemini_service.chat")
    try:
        reply = await gemini_service.chat(
            uid="gemini-integration-phase1",
            messages=messages,
        )
    except Exception as exc:  # pragma: no cover - diagnostic path for integration runs
        pytest.fail(f"phase1 call failed: {type(exc).__name__}: {exc}")

    _step("phase1: validate non-empty textual response")
    assert isinstance(reply, str), f"phase1 response must be str, got {type(reply).__name__}"
    assert reply.strip() != "", "phase1 response must not be empty/whitespace"


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

    _step("phase2: call gemini_service.chat")
    try:
        reply = await gemini_service.chat(
            uid="gemini-integration-phase2",
            messages=messages,
        )
    except Exception as exc:  # pragma: no cover - diagnostic path for integration runs
        pytest.fail(f"phase2 call failed: {type(exc).__name__}: {exc}")

    _step("phase2: parse envelope JSON")
    try:
        envelope = json.loads(reply)
    except json.JSONDecodeError as exc:
        snippet = reply[:400].replace("\n", "\\n")
        pytest.fail(f"phase2 envelope is not valid JSON: {exc}. reply_prefix={snippet!r}")

    _step("phase2: validate envelope keys and metadata")
    expected_envelope_keys = {
        "triptitle",
        "response",
        "recommendations",
    }
    actual_envelope_keys = set(envelope.keys())
    assert (
        actual_envelope_keys == expected_envelope_keys
    ), f"phase2 envelope keys mismatch. expected={expected_envelope_keys}, actual={actual_envelope_keys}"
    assert (
        isinstance(envelope["triptitle"], str) and envelope["triptitle"].strip()
    ), f"phase2 triptitle must be non-empty string, got {envelope['triptitle']!r}"
    assert isinstance(
        envelope["recommendations"], list
    ), f"phase2 recommendations must be list, got {type(envelope['recommendations']).__name__}"
    assert (
        2 <= len(envelope["recommendations"]) <= 4
    ), f"phase2 recommendations count must be 2..4, got {len(envelope['recommendations'])}"
    assert all(
        isinstance(item, str) and item.strip() for item in envelope["recommendations"]
    ), f"phase2 recommendations must contain non-empty strings, got {envelope['recommendations']!r}"

    _step("phase2: validate structured trip payload")
    payload = envelope["response"]
    assert isinstance(
        payload, dict
    ), f"phase2 response payload must be object, got {type(payload).__name__}"

    expected_plan_keys = {"trip_title", "destination", "summary", "hotels", "days", "budget"}
    actual_plan_keys = set(payload.keys())
    assert (
        actual_plan_keys == expected_plan_keys
    ), f"phase2 payload keys mismatch. expected={expected_plan_keys}, actual={actual_plan_keys}"
    assert (
        isinstance(payload["trip_title"], str) and payload["trip_title"].strip()
    ), f"phase2 trip_title must be non-empty string, got {payload['trip_title']!r}"
    assert (
        isinstance(payload["destination"], str) and payload["destination"].strip()
    ), f"phase2 destination must be non-empty string, got {payload['destination']!r}"
    assert isinstance(
        payload["summary"], str
    ), f"phase2 summary must be string, got {type(payload['summary']).__name__}"

    assert (
        isinstance(payload["hotels"], list) and len(payload["hotels"]) >= 1
    ), f"phase2 hotels must be non-empty list, got {payload['hotels']!r}"
    for hotel_night in payload["hotels"]:
        assert {"night", "options"}.issubset(
            hotel_night.keys()
        ), f"phase2 hotel night entry missing required keys: {hotel_night!r}"
        assert isinstance(
            hotel_night["night"], int
        ), f"phase2 hotel night number must be int, got {hotel_night.get('night')!r}"
        if "date" in hotel_night:
            assert isinstance(
                hotel_night["date"], str
            ), f"phase2 hotel night date must be string, got {hotel_night['date']!r}"
        assert (
            isinstance(hotel_night["options"], list) and len(hotel_night["options"]) >= 1
        ), f"phase2 hotel options must be non-empty list, got {hotel_night.get('options')!r}"
        for hotel in hotel_night["options"]:
            assert set(hotel.keys()) == {
                "name",
                "area",
                "nightly_estimate",
                "reason",
            }, f"phase2 hotel option keys mismatch: {hotel!r}"
            assert (
                isinstance(hotel["name"], str) and hotel["name"].strip()
            ), f"phase2 hotel name must be non-empty string, got {hotel.get('name')!r}"

    assert (
        isinstance(payload["days"], list) and len(payload["days"]) >= 1
    ), f"phase2 days must be non-empty list, got {payload['days']!r}"
    for day in payload["days"]:
        assert {"day", "items"}.issubset(
            day.keys()
        ), f"phase2 day entry missing required keys: {day!r}"
        assert isinstance(day["day"], int), f"phase2 day number must be int, got {day.get('day')!r}"
        if "date" in day:
            assert isinstance(
                day["date"], str
            ), f"phase2 day date must be string, got {day.get('date')!r}"
        assert isinstance(
            day["items"], list
        ), f"phase2 day items must be list, got {type(day.get('items')).__name__}"
        for item in day["items"]:
            assert {"time", "title", "description", "category"}.issubset(
                item.keys()
            ), f"phase2 itinerary item missing required keys: {item!r}"
            assert item["category"] in {
                "transport",
                "activity",
                "food",
                "hotel",
                "note",
            }, f"phase2 invalid itinerary category: {item.get('category')!r}"
            if "estimated_cost" in item:
                assert isinstance(
                    item["estimated_cost"], str
                ), f"phase2 estimated_cost must be string when present, got {item.get('estimated_cost')!r}"

    assert {"currency", "estimated_total"}.issubset(
        payload["budget"].keys()
    ), f"phase2 budget missing required keys: {payload['budget']!r}"
    assert (
        isinstance(payload["budget"]["currency"], str) and payload["budget"]["currency"].strip()
    ), f"phase2 budget currency must be non-empty string, got {payload['budget'].get('currency')!r}"
    assert isinstance(
        payload["budget"]["estimated_total"], str
    ), f"phase2 estimated_total must be string, got {type(payload['budget'].get('estimated_total')).__name__}"
    if "notes" in payload["budget"]:
        assert isinstance(
            payload["budget"]["notes"], str
        ), f"phase2 budget notes must be string when present, got {payload['budget'].get('notes')!r}"
