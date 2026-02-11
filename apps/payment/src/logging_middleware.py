import json
import time
import uuid
from collections.abc import Awaitable, Callable

from fastapi import Request, Response

from src.config import settings


async def access_log_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    started = time.perf_counter()
    request_id = request.headers.get("X-Request-Id") or str(uuid.uuid4())

    response = await call_next(request)
    response.headers["X-Request-Id"] = request_id

    entry = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.gmtime()),
        "level": "info",
        "msg": "request completed",
        "service": settings.service_name,
        "env": settings.app_env,
        "requestId": request_id,
        "userId": request.headers.get("X-User-Id", ""),
        "method": request.method,
        "path": request.url.path,
        "status": response.status_code,
        "latency_ms": int((time.perf_counter() - started) * 1000),
        "ip": request.client.host if request.client else "",
        "userAgent": request.headers.get("user-agent", ""),
    }
    print(json.dumps(entry, ensure_ascii=True), flush=True)
    return response
