from __future__ import annotations

from datetime import datetime
from datetime import timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.core.dependencies import get_intelligence_runtime
from app.main import create_app
from app.models import AnswerCard
from app.models import ChatResponse
from app.models import HealthResponse
from app.models import IngestResponse
from app.models import SearchResponse
from app.models import SourceChunk
from app.schemas import AuthTokenResponse
from app.schemas import CurrentUserResponse
from app.schemas import EventRequest
from app.schemas import RepoChatResponse
from app.schemas import RepoChatSource
from app.schemas import RepoIngestionJobResponse
from app.schemas import RepoInsightsResponse
from app.schemas import RepoSearchResponse
from app.schemas import RepoSearchResult
from app.schemas import SystemHealthResponse


NOW = datetime(2026, 1, 1, 12, 0, 0)


def make_user(*, role: str = "developer") -> SimpleNamespace:
    return SimpleNamespace(
        user_id=f"{role}-1",
        username=f"{role}_user",
        email=f"{role}@example.com",
        full_name="Test User",
        country="Ghana",
        phone_number="+233000000000",
        signup_type="developer",
        profile_image=None,
        created_at=NOW,
        terms_accepted_at=NOW,
        last_seen=NOW,
        role=role,
        account_status="active",
        ai_usage_count=2,
        total_tokens_used=40,
        last_ai_interaction=None,
        preferences={"theme": "dark"},
        metadata={"source": "pytest"},
    )


def token_response(user: SimpleNamespace, *, prefix: str = "access") -> AuthTokenResponse:
    return AuthTokenResponse(
        access_token=f"{prefix}-token",
        refresh_token="refresh-token-value-1234567890",
        access_token_expires_in=1800,
        refresh_token_expires_in=2592000,
        session_id="session-1",
        user=CurrentUserResponse.model_validate(user.__dict__),
    )


class FakeAuth:
    def __init__(self) -> None:
        self.developer = make_user(role="developer")
        self.admin = make_user(role="admin")
        self.logout_calls: list[str] = []

    async def resolve_access_token(self, token: str):
        if token == "developer-token":
            return self.developer, SimpleNamespace(session_id="session-1", user_id=self.developer.user_id)
        if token == "admin-token":
            return self.admin, SimpleNamespace(session_id="admin-session", user_id=self.admin.user_id)
        raise ValueError("Invalid access token.")

    async def register(self, payload, **_kwargs):
        return token_response(self.developer, prefix="registered")

    async def login(self, payload, **_kwargs):
        if payload.password == "wrong-password":
            raise ValueError("Invalid email or password.")
        return token_response(self.developer, prefix="logged-in")

    async def refresh(self, _refresh_token: str):
        return token_response(self.developer, prefix="refreshed")

    async def logout(self, session_id: str) -> None:
        self.logout_calls.append(session_id)


class FakeSecurity:
    def __init__(self) -> None:
        self.rate_limited = False

    async def enforce_rate_limit(self, **_kwargs) -> None:
        if self.rate_limited:
            raise ValueError("AI usage rate limit exceeded.")


class FakeTracking:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    async def track_interaction(self, **kwargs):
        self.calls.append(kwargs)


class FakeRepoIngestion:
    def __init__(self) -> None:
        self.raise_enqueue: str | None = None
        self.raise_get = False
        self.job = RepoIngestionJobResponse(
            job_id="job-1",
            repo_name="sample-repo",
            repo_path="/tmp/sample-repo",
            status="queued",
            force_reingest=False,
            created_at=NOW,
            updated_at=NOW,
        )

    async def enqueue(self, payload):
        if self.raise_enqueue:
            if self.raise_enqueue == "runtime":
                raise RuntimeError("Queue unavailable.")
            raise ValueError("Repository path is outside the allowed roots.")
        return self.job

    async def get_job(self, _job_id: str):
        if self.raise_get:
            raise ValueError("Repository ingestion job 'missing' was not found.")
        return self.job


class FakeRepoSearch:
    async def search(self, query: str, repo_name: str | None = None, top_k: int | None = None):
        return RepoSearchResponse(
            query=query,
            repo_name=repo_name,
            mode="semantic_search",
            count=1,
            took_ms=3,
            results=[
                RepoSearchResult(
                    repo_name=repo_name or "sample-repo",
                    file_path="app.py",
                    language="python",
                    chunk_index=0,
                    total_chunks=1,
                    start_line=1,
                    end_line=4,
                    score=0.91,
                    excerpt="def health(): ...",
                )
            ][:top_k or 6],
        )


class FakeRepoChat:
    def __init__(self) -> None:
        self.raise_error = False
        self.calls: list[dict] = []

    async def answer(self, **kwargs):
        self.calls.append(kwargs)
        if self.raise_error:
            raise RuntimeError("provider failed")
        return RepoChatResponse(
            repo_name=kwargs.get("repo_name"),
            question=kwargs["question"],
            answer="The health endpoint reports operational status.",
            sources=[
                RepoChatSource(
                    file_path="app.py",
                    language="python",
                    start_line=1,
                    end_line=4,
                    score=0.91,
                    excerpt="def health(): ...",
                )
            ],
            timings={"total_ms": 4},
        )


class FakeEvents:
    async def record_event(self, payload: EventRequest):
        return SimpleNamespace(
            event_type=payload.event_type,
            timestamp=payload.timestamp or NOW,
        )


class FakeRepoInsights:
    async def list(self, repo_name: str | None = None, limit: int = 100):
        return RepoInsightsResponse(repo_name=repo_name, count=0, insights=[], summary=[])

    async def recommendations(self, repo_name: str | None = None):
        return {
            "repo_name": repo_name,
            "recommendations": [
                {
                    "category": "readiness",
                    "priority": "medium",
                    "recommendation": "Ingest a repository.",
                    "rationale": "No repository insights are stored yet.",
                }
            ],
        }


class FakeAnalytics:
    async def overview(self):
        return {
            "daily_active_users": 4,
            "prompt_count": 12,
            "average_session_duration_s": 35.5,
            "total_tokens_used": 800,
            "most_used_features": [{"feature": "chat", "count": 10}],
        }

    async def usage(self):
        return {"feature_usage": [{"feature": "chat", "count": 10}]}

    async def users_overview(self):
        return {"most_active_users": [{"user_id": "developer-1"}]}

    async def admin_users(self, limit: int = 100):
        return {"users": [{"user_id": "developer-1"}][:limit], "count": 1}

    async def active_sessions(self, limit: int = 100):
        return {"sessions": [{"session_id": "session-1"}][:limit], "count": 1}

    async def ai_usage(self, limit: int = 100):
        return {"usage": [{"feature": "chat", "count": 10}][:limit], "count": 1}

    async def security_alerts(self, limit: int = 100):
        return {"alerts": [{"alert_type": "failed_login"}][:limit], "count": 1}


class FakeLegacyRuntime:
    settings = SimpleNamespace(
        vertex_model="test-vertex-model",
        embedding_model="test-embedding-model",
        vertex_project_id="test-project",
        vertex_location="test-location",
        gcs_bucket="",
        local_chroma_dir=Path("/tmp/test-chroma"),
    )

    def health(self):
        return HealthResponse(
            status="operational",
            provider="test",
            model="test-model",
            project_id="test-project",
            location="test-location",
            collections={"public": "public"},
            vector_db_path="/tmp/test-chroma",
            gcs_bucket="",
            startup_timings={},
        )

    def chat(self, payload, *, extra_context=None):
        async def response():
            return ChatResponse(
                provider="test",
                model="test-model",
                audience=payload.audience,
                answer="A test answer.",
                answer_cards=[AnswerCard(title="Summary", category="test", summary="Summary")],
                suggested_follow_ups=["Ask another question"],
                sources=[],
                timings={"totalMs": 1},
                debug={"extra_context": bool(extra_context)},
            )

        return response()

    async def search(self, payload):
        return SearchResponse(audience=payload.audience, count=0, sources=[])

    async def ingest(self, *, files, audience: str):
        return IngestResponse(
            accepted_files=len(files),
            target_collection=audience,
            uploaded_to_gcs=False,
            chunks_inserted=1,
            vector_db_path="/tmp/test-chroma",
        )


class FakeIntelligenceRuntime:
    def __init__(self) -> None:
        self.settings = SimpleNamespace(
            ai_request_rate_limit=10,
            gemini_reasoning_model="test-reasoning-model",
            gemini_embedding_model="test-embedding-model",
        )
        self.auth = FakeAuth()
        self.security = FakeSecurity()
        self.tracking = FakeTracking()
        self.repo_ingestion = FakeRepoIngestion()
        self.repo_search = FakeRepoSearch()
        self.repo_chat = FakeRepoChat()
        self.events = FakeEvents()
        self.repo_insights = FakeRepoInsights()
        self.analytics = FakeAnalytics()

    async def system_health(self):
        return {
            "status": "operational",
            "allowed_roots": ["/tmp"],
            "components": {
                "mongodb": {"status": "operational", "detail": "ok", "metrics": {}}
            },
            "queues": {"repo-ingestion": 0},
            "latest_jobs": [],
        }


@pytest.fixture
def intelligence_runtime() -> FakeIntelligenceRuntime:
    return FakeIntelligenceRuntime()


@pytest.fixture
def client(intelligence_runtime: FakeIntelligenceRuntime):
    app = create_app()
    app.state.runtime = FakeLegacyRuntime()
    app.state.intelligence_runtime = intelligence_runtime
    app.dependency_overrides[get_intelligence_runtime] = lambda: intelligence_runtime
    test_client = TestClient(app, raise_server_exceptions=False)
    yield test_client
    test_client.close()
    app.dependency_overrides.clear()


@pytest.fixture
def auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer developer-token"}


@pytest.fixture
def admin_headers() -> dict[str, str]:
    return {"Authorization": "Bearer admin-token"}
