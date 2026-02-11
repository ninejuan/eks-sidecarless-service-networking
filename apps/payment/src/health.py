from fastapi import APIRouter, Response, status

from src.config import settings
from src.models import HealthResponse

health_router = APIRouter(tags=["health"])


@health_router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(service=settings.service_name, status="ok", version="v1")


@health_router.get("/health/liveness")
async def liveness() -> dict[str, str]:
    return {"status": "alive"}


@health_router.get("/health/readiness")
async def readiness(response: Response) -> dict[str, str]:
    ready = True
    if not ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready"}
    return {"status": "ready"}
