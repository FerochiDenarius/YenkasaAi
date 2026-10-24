from __future__ import annotations

from fastapi import BackgroundTasks
from fastapi import APIRouter
from fastapi import Depends
from fastapi import Header
from fastapi import HTTPException
from fastapi import Query
from fastapi import Request

from app.core.dependencies import get_intelligence_runtime
from app.modules.security import require_admin_user
from app.modules.security import require_current_user
from app.modules.security import require_roles
from app.schemas import EventIngestResponse
from app.schemas import EventRequest
from app.schemas import LogAlertsResponse
from app.schemas import LogIngestRequest
from app.schemas import LogIngestResponse
from app.schemas import GitHubSyncRequest
from app.schemas import GitHubSyncResponse
from app.schemas import RecommendationsResponse
from app.schemas import RepoChatRequest
from app.schemas import RepoChatResponse
from app.schemas import RepoIngestionJobResponse
from app.schemas import RepoIngestionRequest
from app.schemas import RepoInsightsResponse
from app.schemas import RepoSearchResponse
from app.schemas import SystemComponentHealth
from app.schemas import SystemHealthResponse


router = APIRouter(prefix="/api", tags=["dev-intelligence"])


def _validate_log_ingest_key(runtime, provided_key: str | None) -> None:
    expected_key = runtime.settings.log_ingest_api_key.strip()
    if expected_key and provided_key != expected_key:
        raise HTTPException(status_code=401, detail="Invalid log ingestion key.")


def _authorize_event_ingest(request: Request, runtime, provided_key: str | None) -> dict[str, str]:
    configured_keys = {
        runtime.settings.event_ingest_api_key.strip(),
        runtime.settings.internal_platform_api_key.strip(),
    }
    configured_keys.discard("")

    if provided_key and provided_key in configured_keys:
        return {"mode": "api_key", "subject": "backend_service"}

    current_user = getattr(request.state, "current_user", None)
    auth_error = getattr(request.state, "auth_error", None)
    if current_user is not None and current_user.role in {"developer", "senior_developer", "admin", "super_admin"}:
        return {"mode": "user", "subject": current_user.user_id}

    if auth_error:
        raise HTTPException(status_code=401, detail=str(auth_error))

    if configured_keys:
        raise HTTPException(status_code=401, detail="Invalid or missing event ingestion credentials.")
    raise HTTPException(status_code=401, detail="Event ingestion API key is not configured.")


@router.post("/logs", response_model=LogIngestResponse)
async def ingest_log_event(
    payload: LogIngestRequest,
    runtime=Depends(get_intelligence_runtime),
    x_log_api_key: str | None = Header(default=None, alias="X-Log-Api-Key"),
) -> LogIngestResponse:
    _validate_log_ingest_key(runtime, x_log_api_key)
    try:
        return await runtime.logs.ingest(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/repo/ingestion", response_model=RepoIngestionJobResponse)
@router.post("/repo/ingestions", response_model=RepoIngestionJobResponse)
async def enqueue_repo_ingestion(
    payload: RepoIngestionRequest,
    developer=Depends(require_roles("developer", "senior_developer", "admin", "super_admin")),
    runtime=Depends(get_intelligence_runtime),
) -> RepoIngestionJobResponse:
    _ = developer
    try:
        return await runtime.repo_ingestion.enqueue(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/repo/ingestion/{job_id}", response_model=RepoIngestionJobResponse)
@router.get("/repo/ingestions/{job_id}", response_model=RepoIngestionJobResponse)
async def get_repo_ingestion_job(
    job_id: str,
    developer=Depends(require_roles("developer", "senior_developer", "admin", "super_admin")),
    runtime=Depends(get_intelligence_runtime),
) -> RepoIngestionJobResponse:
    _ = developer
    try:
        return await runtime.repo_ingestion.get_job(job_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/repo/search", response_model=RepoSearchResponse)
async def repo_search(
    request: Request,
    q: str = Query(min_length=1),
    repo_name: str | None = None,
    top_k: int | None = Query(default=None, ge=1, le=20),
    current_user=Depends(require_current_user),
    runtime=Depends(get_intelligence_runtime),
) -> RepoSearchResponse:
    current_session = getattr(request.state, "current_session", None)
    if current_session is None:
        raise HTTPException(status_code=401, detail="Active session is required.")
    try:
        await runtime.security.enforce_rate_limit(
            key=f"ai:repo-search:{current_user.user_id}",
            limit=runtime.settings.ai_request_rate_limit,
            window_s=60,
            error_message="AI usage rate limit exceeded.",
        )
    except ValueError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    response = await runtime.repo_search.search(query=q, repo_name=repo_name, top_k=top_k)
    await runtime.tracking.track_interaction(
        user=current_user,
        session=current_session,
        feature="repo_search",
        request_path=str(request.url.path),
        prompt=q,
        response_text="\n".join(result.file_path for result in response.results),
        response_time_ms=response.took_ms,
        model_used=runtime.settings.gemini_embedding_model,
        metadata={"repo_name": repo_name, "count": response.count},
    )
    return response


@router.post("/repo/chat", response_model=RepoChatResponse)
async def repo_chat(
    payload: RepoChatRequest,
    request: Request,
    current_user=Depends(require_current_user),
    runtime=Depends(get_intelligence_runtime),
) -> RepoChatResponse:
    current_session = getattr(request.state, "current_session", None)
    if current_session is None:
        raise HTTPException(status_code=401, detail="Active session is required.")
    try:
        await runtime.security.enforce_rate_limit(
            key=f"ai:repo-chat:{current_user.user_id}",
            limit=runtime.settings.ai_request_rate_limit,
            window_s=60,
            error_message="AI usage rate limit exceeded.",
        )
    except ValueError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    response = await runtime.repo_chat.answer(
        question=payload.question,
        repo_name=payload.repo_name,
        top_k=payload.top_k,
        include_sources=payload.include_sources,
    )
    await runtime.tracking.track_interaction(
        user=current_user,
        session=current_session,
        feature="repo_chat",
        request_path=str(request.url.path),
        prompt=payload.question,
        response_text=response.answer,
        response_time_ms=response.timings.get("total_ms", 0),
        model_used=runtime.settings.gemini_reasoning_model,
        metadata={"repo_name": payload.repo_name},
    )
    return response


@router.post("/events", response_model=EventIngestResponse, status_code=202)
@router.post("/events/ingest", response_model=EventIngestResponse, status_code=202)
async def ingest_event(
    payload: EventRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    runtime=Depends(get_intelligence_runtime),
    x_event_api_key: str | None = Header(default=None, alias="X-Event-Api-Key"),
) -> EventIngestResponse:
    auth_context = _authorize_event_ingest(request, runtime, x_event_api_key)
    try:
        await runtime.security.enforce_rate_limit(
            key=f"events:ingest:{auth_context['subject']}:{payload.source}",
            limit=runtime.settings.event_ingest_rate_limit,
            window_s=60,
            error_message="Event ingestion rate limit exceeded.",
        )
    except ValueError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc

    event = await runtime.events.record_event(payload, capture_memory=False)
    background_tasks.add_task(runtime.events.process_event_document, event.model_dump(mode="python"))
    return EventIngestResponse(
        status="accepted",
        event_id=event.event_id,
        event_type=event.event_type,
        source=event.source,
        queued_for_processing=True,
        processing_status=event.processing_status,
        stored_at=event.ingested_at,
    )


@router.get("/alerts", response_model=LogAlertsResponse)
async def list_log_alerts(
    request: Request,
    service: str | None = None,
    severity: str | None = None,
    limit: int = Query(default=25, ge=1, le=100),
    current_user=Depends(require_current_user),
    runtime=Depends(get_intelligence_runtime),
) -> LogAlertsResponse:
    current_session = getattr(request.state, "current_session", None)
    if current_session is None:
        raise HTTPException(status_code=401, detail="Active session is required.")
    _ = current_user
    return await runtime.logs.list_alerts(limit=limit, service=service, severity=severity)


@router.get("/admin/repo-insights", response_model=RepoInsightsResponse)
async def admin_repo_insights(
    repo_name: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
    admin_user=Depends(require_admin_user),
    runtime=Depends(get_intelligence_runtime),
) -> RepoInsightsResponse:
    _ = admin_user
    return await runtime.repo_insights.list(repo_name=repo_name, limit=limit)


@router.post("/admin/github/sync", response_model=GitHubSyncResponse)
async def admin_github_sync(
    payload: GitHubSyncRequest,
    admin_user=Depends(require_admin_user),
    runtime=Depends(get_intelligence_runtime),
) -> GitHubSyncResponse:
    _ = admin_user
    result = await runtime.github.sync_repository_from_payload(payload.model_dump(exclude_none=True))
    return GitHubSyncResponse(**result)


@router.get("/admin/system-health", response_model=SystemHealthResponse)
async def admin_system_health(
    admin_user=Depends(require_admin_user),
    runtime=Depends(get_intelligence_runtime),
) -> SystemHealthResponse:
    _ = admin_user
    payload = await runtime.system_health()
    components = {
        name: SystemComponentHealth(**details)
        for name, details in payload["components"].items()
    }
    return SystemHealthResponse(
        status=payload["status"],
        allowed_roots=payload["allowed_roots"],
        components=components,
        queues=payload["queues"],
        latest_jobs=payload["latest_jobs"],
    )


@router.get("/admin/recommendations", response_model=RecommendationsResponse)
async def admin_recommendations(
    repo_name: str | None = None,
    admin_user=Depends(require_admin_user),
    runtime=Depends(get_intelligence_runtime),
) -> RecommendationsResponse:
    _ = admin_user
    return await runtime.repo_insights.recommendations(repo_name=repo_name)
