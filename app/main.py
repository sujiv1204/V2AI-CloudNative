from fastapi import FastAPI
from app.api.routes import router
import logging
import os

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

app = FastAPI(title="ML Pipeline Service")

app.include_router(router)


# ---------------------------
# HEALTH CHECK (K8s REQUIRED)
# ---------------------------
@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    return {"status": "ready"}