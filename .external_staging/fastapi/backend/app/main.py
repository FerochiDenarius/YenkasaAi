from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router as legacy_ai_router
from app.api.admin_routes import router as admin_router
from app.api.auth_routes import router as auth_router
from app.config import get_settings
from app.api.intelligence_routes import router as intelligence_router
from app.api.platform_routes import router as platform_router
from app.api.yme_routes import router as yme_router
from app.core.logging import configure_logging
from app.core.runtime import IntelligenceRuntime
from app.middleware import AuthContextMiddleware
from app.middleware import RequestContextMiddleware
from services.rag_service import RagRuntime


LOGGER = logging.getLogger("yenkasa_ai_cloud.app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    configure_logging(settings.log_level)
    runtime = RagRuntime(settings)
    intelligence_runtime = IntelligenceRuntime(settings)
    runtime.startup()
    try:
        await intelligence_runtime.startup()
    except Exception:
        LOGGER.exception("Dev intelligence startup failed; core chat endpoints will remain available.")
    app.state.settings = settings
    app.state.runtime = runtime
    app.state.intelligence_runtime = intelligence_runtime
    try:
        yield
    finally:
        try:
            await intelligence_runtime.shutdown()
        except Exception:
            LOGGER.exception("Dev intelligence shutdown failed")
        runtime.shutdown()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="2.0.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(AuthContextMiddleware)
    app.add_middleware(RequestContextMiddleware)
    
    app.include_router(legacy_ai_router)
    app.include_router(auth_router)
    app.include_router(admin_router)
    app.include_router(intelligence_router)
    app.include_router(platform_router)
    app.include_router(yme_router)
    return app


app = create_app()
