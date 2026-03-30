import os
import time
from datetime import datetime, timezone
from typing import Any, Callable, Dict, Tuple

from fastapi import APIRouter, FastAPI, Request, Response

CACHE_TTL_SEC = max(1, int(os.environ.get("CACHE_TTL_SEC", "60") or "60"))

_cache: Dict[str, Tuple[float, Any]] = {}


def get_cached(key: str, producer: Callable[[], Any]) -> tuple[bool, Any]:
    now = time.monotonic()
    entry = _cache.get(key)
    if entry is not None:
        expires_at, value = entry
        if expires_at > now:
            return True, value
    value = producer()
    _cache[key] = (now + CACHE_TTL_SEC, value)
    return False, value


router = APIRouter()


@router.get("/time")
def server_time(response: Response) -> dict:
    hit, body = get_cached(
        "time",
        lambda: {
            "serverTime": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        },
    )
    response.headers["X-Cache"] = "HIT" if hit else "MISS"
    response.headers["Cache-Control"] = f"private, max-age={CACHE_TTL_SEC}"
    return body


@router.get("/health")
def health() -> str:
    return "health"


def _normalized_prefix() -> str:
    raw = os.environ.get("PATH_PREFIX", "").strip().rstrip("/")
    if not raw:
        return ""
    return raw if raw.startswith("/") else f"/{raw}"


app = FastAPI(title="Python time API")
_prefix = _normalized_prefix()
if _prefix:
    app.include_router(router, prefix=_prefix)
else:
    app.include_router(router)


@app.middleware("http")
async def apigateway_rest_path_fix(request: Request, call_next):
    """Normalize path for REST API + {proxy+} and optional API Gateway stage prefix."""
    scope = request.scope
    path = scope.get("path") or "/"

    stage = os.environ.get("API_GATEWAY_STAGE_NAME", "").strip()
    if stage:
        sp = f"/{stage}"
        if path == sp or path.startswith(f"{sp}/"):
            path = path[len(sp) :] or "/"

    prefix = _normalized_prefix()
    if prefix and path.startswith("/") and path != prefix and not path.startswith(f"{prefix}/"):
        path = f"{prefix}{path if path != '/' else ''}"

    if path != request.scope.get("path"):
        request.scope["path"] = path

    return await call_next(request)
