from __future__ import annotations

import asyncio
from contextlib import suppress
import logging
from datetime import datetime

from app.modules.analytics import AnalyticsService
from app.modules.auth import AuthService
from app.modules.embeddings import EmbeddingsService
from app.modules.events import EventService
from app.modules.events import LogIntelligenceService
from app.modules.repo_chat import RepoChatService
from app.modules.github import GitHubSyncService
from app.modules.repo_ingestion import RepoIngestionService
from app.modules.repo_ingestion import RepositoryScanner
from app.modules.repo_insights import RepoInsightsService
from app.modules.repo_search import RepoSearchService
from app.modules.security import PasswordService
from app.modules.security import SecurityService
from app.modules.security import TokenService
from app.modules.sessions import SessionService
from app.modules.tracking import AITrackingService
from app.modules.users import UserService
from app.modules.vector_search import MongoVectorSearchService
from app.modules.yme import YMETrackingService
from app.services import GeminiService
from app.services import MongoService
from app.services import QueueService


LOGGER = logging.getLogger("yenkasa_ai_cloud.intelligence_runtime")


class IntelligenceRuntime:
    def __init__(self, settings) -> None:
        self.settings = settings
        self.mongo = MongoService(settings)
        self.queue = QueueService(settings)
        self.gemini = GeminiService(settings)
        self.passwords = PasswordService()
        self.tokens = TokenService(settings)
        self.security = SecurityService(settings, self.mongo, self.queue, self.passwords, self.tokens)
        self.users = UserService(self.mongo, self.passwords)
        self.sessions = SessionService(settings, self.mongo, self.security)
        self.embeddings = EmbeddingsService(settings, self.gemini)
        self.yme = YMETrackingService(self.settings, self.mongo, self.embeddings)
        self.tracking = AITrackingService(settings, self.mongo, self.users, self.yme)
        self.auth = AuthService(settings, self.users, self.sessions, self.security)
        self.analytics = AnalyticsService(self.mongo, self.users, self.sessions, self.security)
        self.logs = LogIntelligenceService(settings, self.mongo)
        self.vector_search = MongoVectorSearchService(settings, self.mongo)
        self.repo_search = RepoSearchService(settings, self.embeddings, self.vector_search)
        self.repo_insights = RepoInsightsService(settings, self.mongo, self.vector_search)
        self.repo_chat = RepoChatService(self.repo_search, self.gemini)
        self.repo_ingestion = RepoIngestionService(
            settings=settings,
            mongo_service=self.mongo,
            queue_service=self.queue,
            scanner=RepositoryScanner(settings),
            embeddings_service=self.embeddings,
            vector_service=self.vector_search,
            insights_service=self.repo_insights,
        )
        self.github = GitHubSyncService(settings, self.mongo, self.repo_ingestion)
        self.events = EventService(self.mongo, self.yme)
        self.github_bootstrap_task: asyncio.Task | None = None
        self.github_bootstrap_state: dict[str, object] = {
            "status": "idle",
            "started_at": None,
            "finished_at": None,
            "error": None,
            "summary": None,
        }

    async def startup(self) -> None:
        if not self.settings.dev_intelligence_enabled:
            LOGGER.warning("Dev intelligence runtime disabled by configuration.")
            return

        await self.mongo.connect()
        await self.queue.connect()
        await self.yme.ensure_indexes()
        await self.vector_search.ensure_indexes()

        if self.settings.github_scan_all_repos and self.settings.github_token.strip():
            self.github_bootstrap_task = asyncio.create_task(self._bootstrap_github_sync())

    async def _bootstrap_github_sync(self) -> None:
        if self.github_bootstrap_state.get("status") in {"running", "completed"}:
            return

        self.github_bootstrap_state.update(
            {
                "status": "running",
                "started_at": datetime.utcnow().isoformat(),
                "finished_at": None,
                "error": None,
                "summary": None,
            }
        )

        try:
            summary = await self.github.sync_all_accessible_repositories(
                owner=self.settings.github_owner or None,
                force_reingest=False,
            )
        except Exception as exc:
            self.github_bootstrap_state.update(
                {
                    "status": "failed",
                    "finished_at": datetime.utcnow().isoformat(),
                    "error": str(exc),
                    "summary": None,
                }
            )
            LOGGER.exception("GitHub bootstrap sync failed.")
            return

        self.github_bootstrap_state.update(
            {
                "status": summary.get("status", "completed"),
                "finished_at": datetime.utcnow().isoformat(),
                "error": None,
                "summary": {
                    "synced_count": summary.get("synced_count", 0),
                    "failed_count": summary.get("failed_count", 0),
                    "repositories": summary.get("repositories", [])[:5],
                },
            }
        )
        LOGGER.info(
            "GitHub bootstrap sync finished.",
            extra={
                "github_bootstrap_state": self.github_bootstrap_state,
            },
        )

    async def shutdown(self) -> None:
        if self.github_bootstrap_task is not None and not self.github_bootstrap_task.done():
            self.github_bootstrap_task.cancel()
            with suppress(asyncio.CancelledError):
                await self.github_bootstrap_task
        await self.queue.close()
        await self.mongo.close()

    async def system_health(self) -> dict:
        components: dict[str, dict] = {}
        status = "operational"

        try:
            await self.mongo.ping()
            components["mongodb"] = {
                "status": "operational",
                "detail": "MongoDB Atlas connection healthy.",
                "metrics": {"database": self.settings.mongodb_database},
            }
        except Exception as exc:
            status = "degraded"
            components["mongodb"] = {"status": "degraded", "detail": str(exc), "metrics": {}}

        try:
            await self.queue.ping()
            redis_detail = "Redis queue reachable."
            if not self.queue.queue_capable():
                redis_detail = (
                    "Upstash REST Redis reachable for rate limiting and transient storage. "
                    "Repo ingestion queue still requires REDIS_URL."
                )
            components["redis"] = {
                "status": "operational",
                "detail": redis_detail,
                "metrics": {
                    "mode": self.queue.redis_mode(),
                    "queue": self.settings.repo_ingestion_queue_name,
                    "queue_enabled": self.queue.queue_capable(),
                },
            }
        except Exception as exc:
            status = "degraded"
            components["redis"] = {"status": "degraded", "detail": str(exc), "metrics": {}}

        components["gemini"] = {
            "status": "operational" if self.gemini.configured else "degraded",
            "detail": (
                f"Gemini models configured ({self.settings.gemini_reasoning_model}, {self.settings.gemini_embedding_model})."
                if self.gemini.configured
                else "Gemini configuration is incomplete."
            ),
            "metrics": {},
        }
        components["auth"] = {
            "status": "operational" if bool(self.settings.jwt_secret_key and self.settings.mongodb_uri) else "degraded",
            "detail": "JWT identity layer configured." if self.settings.jwt_secret_key else "JWT secret is missing.",
            "metrics": {},
        }
        components["logs"] = {
            "status": "operational" if self.mongo.configured else "degraded",
            "detail": "Log aggregation and alerting are configured." if self.mongo.configured else "MongoDB is unavailable.",
            "metrics": {
                "logs_collection": self.settings.mongodb_logs_collection,
                "alerts_collection": self.settings.mongodb_log_alerts_collection,
            },
        }
        components["platform_ingestion"] = {
            "status": "operational" if bool(self.settings.internal_platform_api_key) else "degraded",
            "detail": (
                "Internal platform ingestion key configured."
                if self.settings.internal_platform_api_key
                else "Internal platform ingestion key is missing."
            ),
            "metrics": {
                "events_collection": self.settings.mongodb_events_collection,
                "logs_collection": self.settings.mongodb_logs_collection,
            },
        }
        components["github"] = {
            "status": "operational" if bool(self.settings.github_token) else "degraded",
            "detail": (
                "GitHub token configured and repository cache available."
                if self.settings.github_token
                else "GitHub token is missing."
            ),
            "metrics": {
                "owner": self.settings.github_owner or "all-accessible",
                "scan_all_repos": self.settings.github_scan_all_repos,
                "cache_root": str(self.settings.github_repo_cache_root),
                "bootstrap": self.github_bootstrap_state,
            },
        }
        components["yme"] = {
            "status": "operational" if self.settings.yme_enabled and self.mongo.configured else "degraded",
            "detail": "YME v2 memory services configured." if self.settings.yme_enabled else "YME v2 is disabled.",
            "metrics": {
                "events_collection": self.settings.mongodb_yme_collection,
                "memories_collection": self.settings.mongodb_yme_memories_collection,
                "graph_collection": self.settings.mongodb_yme_graph_collection,
                "vector_index": self.settings.mongodb_yme_vector_index_name,
            },
        }

        queue_depths = await self.queue.get_queue_depths() if self.queue.queue_capable() else {}
        latest_jobs = await self.vector_search.latest_jobs(limit=5) if self.mongo.configured else []

        if not self.settings.dev_intelligence_enabled:
            status = "disabled"

        return {
            "status": status,
            "allowed_roots": [str(path) for path in self.settings.repo_allowed_roots],
            "components": components,
            "queues": queue_depths,
            "latest_jobs": latest_jobs,
        }
