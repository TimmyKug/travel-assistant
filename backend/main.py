import json
import logging
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from routers import ai, trips, auth, health

# ---------------------------------------------------------------------------
# Structured JSON logging
# ---------------------------------------------------------------------------

_STANDARD_LOG_ATTRS = frozenset({
    "args", "created", "exc_info", "exc_text", "filename", "funcName",
    "levelname", "levelno", "lineno", "message", "module", "msecs",
    "msg", "name", "pathname", "process", "processName", "relativeCreated",
    "stack_info", "thread", "threadName", "taskName",
})


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        record.message = record.getMessage()
        log: dict = {
            "level":   record.levelname,
            "logger":  record.name,
            "message": record.message,
            "time":    self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
        }
        extras = {k: v for k, v in record.__dict__.items() if k not in _STANDARD_LOG_ATTRS}
        log.update(extras)
        if record.exc_info:
            log["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(log, default=str)


def _configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(_JsonFormatter())
    logging.root.setLevel(logging.INFO)
    logging.root.handlers = [handler]
    # Uvicorn's access log is redundant — prometheus already tracks requests
    logging.getLogger("uvicorn.access").propagate = False


_configure_logging()

# ---------------------------------------------------------------------------

app = FastAPI(
    title="AI Travel Assistant API",
    version="1.0.0",
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Expose /metrics for Prometheus scraping
Instrumentator().instrument(app).expose(app)

app.include_router(auth.router,  prefix="/api/auth",  tags=["auth"])
app.include_router(ai.router,    prefix="/api/ai",    tags=["ai"])
app.include_router(trips.router, prefix="/api/trips", tags=["trips"])
app.include_router(health.router, prefix="/api", tags=["health"])


@app.get("/api/health")
def health_check():
    return {"status": "ok"}
