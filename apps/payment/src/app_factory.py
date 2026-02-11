from fastapi import FastAPI

from src.config import settings
from src.health import health_router
from src.logging_middleware import access_log_middleware
from src.routes import router


def create_app() -> FastAPI:
    app = FastAPI(title="payment-service", version="1.0.0")
    app.middleware("http")(access_log_middleware)
    app.include_router(health_router)
    app.include_router(router)
    return app
