"""
Application-level Prometheus metrics.

Import and increment these in routers/services rather than creating
counters inline — prometheus_client raises on duplicate registration.
"""

from prometheus_client import Counter, Histogram

auth_events_total = Counter(
    "auth_events_total",
    "Authentication events by type",
    ["event"],  # register | login_success | login_failure
)
# Pre-initialise so all label values appear in /metrics from startup
auth_events_total.labels(event="register")
auth_events_total.labels(event="login_success")
auth_events_total.labels(event="login_failure")

ai_requests_total = Counter(
    "ai_requests_total",
    "AI chat requests by outcome",
    ["status"],  # success | rate_limited | error
)

gemini_duration_seconds = Histogram(
    "gemini_request_duration_seconds",
    "Wall-clock time for each Gemini API call",
    buckets=[0.5, 1.0, 2.0, 5.0, 10.0, 30.0],
)

trips_operations_total = Counter(
    "trips_operations_total",
    "Trip CRUD operations by type",
    ["operation"],  # create | update | delete
)
