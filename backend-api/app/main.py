import logging
import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from app.config import settings
from app.db.session import engine, Base
from app.api.auth import router as auth_router
from app.api.dependents import router as dependents_router
from app.api.medications import router as medications_router
from app.api.ai import router as ai_router

# Configure root logger
log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)
logging.basicConfig(
    level=log_level,
    format="%(asctime)s [%(levelname)s] [%(name)s]: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("gobi.api")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Starting {settings.PROJECT_NAME} (ENV={settings.ENV}, LOG_LEVEL={settings.LOG_LEVEL})")
    # Create tables if not exist on startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()
    logger.info("Application shutdown complete.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan
)

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        client_host = request.client.host if request.client else "unknown"
        logger.debug(f"--> {request.method} {request.url.path} (Client: {client_host})")
        
        try:
            response: Response = await call_next(request)
            duration_ms = (time.time() - start_time) * 1000
            
            if response.status_code >= 400:
                logger.warning(
                    f"<-- {request.method} {request.url.path} -> {response.status_code} "
                    f"[{duration_ms:.1f}ms] (Client: {client_host})"
                )
            else:
                logger.debug(
                    f"<-- {request.method} {request.url.path} -> {response.status_code} "
                    f"[{duration_ms:.1f}ms]"
                )
            return response
        except Exception as exc:
            duration_ms = (time.time() - start_time) * 1000
            logger.exception(
                f"<-- EXCEPTION on {request.method} {request.url.path} after {duration_ms:.1f}ms: {exc}"
            )
            raise

app.add_middleware(RequestLoggingMiddleware)

# CORS
if "*" in settings.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r".*",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Health Check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "gobi-backend-api",
        "env": settings.ENV,
        "version": settings.VERSION
    }

# Register API v1 routers
v1_prefix = "/api/v1"
app.include_router(auth_router, prefix=v1_prefix)
app.include_router(dependents_router, prefix=v1_prefix)
app.include_router(medications_router, prefix=v1_prefix)
app.include_router(ai_router, prefix=v1_prefix)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.PORT, reload=True)
