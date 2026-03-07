from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from routers import ai, trips, auth

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


@app.get("/health")
def health_check():
    return {"status": "ok"}
