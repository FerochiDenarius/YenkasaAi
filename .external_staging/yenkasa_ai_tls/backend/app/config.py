from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv


HF_SNAPSHOT_ROOT = (
    Path.home()
    / ".cache"
    / "huggingface"
    / "hub"
    / "models--sentence-transformers--all-MiniLM-L6-v2"
    / "snapshots"
)

BACKEND_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND_ROOT / ".env", override=False)


def parse_csv(value: str | None, default: list[str]) -> list[str]:
    if not value:
        return default
    return [item.strip() for item in value.split(",") if item.strip()]


def parse_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def parse_paths_csv(value: str | None, default: list[Path]) -> list[Path]:
    if not value:
        return default
    return [Path(item.strip()).expanduser().resolve() for item in value.split(",") if item.strip()]


def resolve_embedding_model() -> str:
    configured = os.getenv("EMBEDDING_MODEL")
    if configured:
        return configured

    if HF_SNAPSHOT_ROOT.exists():
        snapshots = sorted(path for path in HF_SNAPSHOT_ROOT.iterdir() if path.is_dir())
        if snapshots:
            return str(snapshots[-1].resolve())

    return "sentence-transformers/all-MiniLM-L6-v2"


@dataclass(frozen=True)
class Settings:
    app_name: str
    environment: str
    log_level: str
    host: str
    port: int
    cors_allow_origins: list[str]
    vertex_project_id: str
    vertex_location: str
    vertex_model: str
    vertex_temperature: float
    retrieval_k: int
    max_history_turns: int
    engineering_collection_name: str
    public_collection_name: str
    embedding_model: str
    local_workdir: Path
    local_chroma_dir: Path
    local_upload_dir: Path
    gcs_bucket: str
    gcs_chroma_prefix: str
    gcs_knowledge_prefix: str
    public_bootstrap_dir: Path | None
    dev_intelligence_enabled: bool
    mongodb_uri: str
    mongodb_database: str
    mongodb_server_selection_timeout_ms: int
    mongodb_chunks_collection: str
    mongodb_jobs_collection: str
    mongodb_insights_collection: str
    mongodb_events_collection: str
    mongodb_users_collection: str
    mongodb_sessions_collection: str
    mongodb_yme_collection: str
    mongodb_yme_memories_collection: str
    mongodb_yme_graph_collection: str
    mongodb_conversations_collection: str
    mongodb_security_alerts_collection: str
    mongodb_logs_collection: str
    mongodb_log_alerts_collection: str
    mongodb_moderation_alerts_collection: str
    mongodb_engagement_metrics_collection: str
    mongodb_ai_insights_collection: str
    mongodb_github_repositories_collection: str
    mongodb_repo_architecture_collection: str
    mongodb_vector_index_name: str
    mongodb_vector_dimensions: int
    mongodb_yme_vector_index_name: str
    mongodb_yme_vector_dimensions: int
    redis_url: str
    upstash_redis_rest_url: str
    upstash_redis_rest_token: str
    repo_ingestion_queue_name: str
    repo_ingestion_job_timeout_s: int
    github_sync_queue_name: str
    github_sync_job_timeout_s: int
    repo_allowed_roots: list[Path]
    repo_chunk_max_lines: int
    repo_chunk_overlap_lines: int
    repo_file_size_limit_bytes: int
    repo_insight_large_file_lines: int
    repo_search_top_k: int
    repo_search_num_candidates: int
    github_token: str
    github_owner: str
    github_scan_all_repos: bool
    github_repo_cache_root: Path
    github_clone_depth: int
    github_scan_max_files: int
    github_metadata_cache_ttl_s: int
    github_low_rate_limit_threshold: int
    log_spike_threshold: int
    log_spike_multiplier: int
    log_spike_window_minutes: int
    log_stack_window_minutes: int
    log_stack_repeat_threshold: int
    log_alert_suppression_minutes: int
    log_ingest_api_key: str
    internal_platform_api_key: str
    event_ingest_api_key: str
    internal_platform_batch_rate_limit: int
    internal_platform_health_rate_limit: int
    event_ingest_rate_limit: int
    gemini_reasoning_model: str
    gemini_embedding_model: str
    embedding_batch_size: int
    embedding_retry_attempts: int
    jwt_secret_key: str
    jwt_algorithm: str
    access_token_ttl_minutes: int
    refresh_token_ttl_days: int
    auth_window_seconds: int
    auth_login_rate_limit: int
    auth_register_rate_limit: int
    ai_request_rate_limit: int
    max_concurrent_sessions: int
    yme_enabled: bool
    yme_embedding_enabled: bool
    yme_min_importance_score: float
    yme_memory_search_limit: int
    yme_memory_injection_limit: int
    yme_memory_context_char_budget: int
    yme_memory_cleanup_days: int


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    project_root = Path(__file__).resolve().parents[2]
    local_workdir = Path(os.getenv("LOCAL_WORKDIR", "/tmp/yenkasa-ai")).resolve()
    repo_cache_root = Path(os.getenv("GITHUB_REPO_CACHE_ROOT", str(local_workdir / "repo_cache"))).resolve()
    bootstrap_dir_raw = os.getenv("PUBLIC_KNOWLEDGE_BOOTSTRAP_DIR")
    bootstrap_dir = Path(bootstrap_dir_raw).resolve() if bootstrap_dir_raw else None
    default_repo_roots = [project_root, local_workdir, repo_cache_root, Path("/tmp")]

    return Settings(
        app_name=os.getenv("APP_NAME", "YenkasaAI Cloud Backend"),
        environment=os.getenv("APP_ENV", "development"),
        log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8080")),
        cors_allow_origins=parse_csv(
            os.getenv("CORS_ALLOW_ORIGINS"),
            ["http://localhost:5174", "http://127.0.0.1:5174"],
        ),
        vertex_project_id=os.getenv("VERTEX_AI_PROJECT_ID", "project-10405180-0afd-4ecc-9f8"),
        vertex_location=os.getenv("VERTEX_AI_LOCATION", "us-central1"),
        vertex_model=os.getenv("VERTEX_AI_MODEL", "gemini-2.5-flash"),
        vertex_temperature=float(os.getenv("VERTEX_AI_TEMPERATURE", "0.2")),
        retrieval_k=int(os.getenv("RETRIEVAL_K", "5")),
        max_history_turns=int(os.getenv("MAX_HISTORY_TURNS", "6")),
        engineering_collection_name=os.getenv("CHROMA_COLLECTION_NAME", "yenkasa_research"),
        public_collection_name=os.getenv("CHROMA_PUBLIC_COLLECTION_NAME", "yenkasa_platform_knowledge"),
        embedding_model=resolve_embedding_model(),
        local_workdir=local_workdir,
        local_chroma_dir=(local_workdir / "chroma_db"),
        local_upload_dir=(local_workdir / "uploads"),
        gcs_bucket=os.getenv("GCS_BUCKET", ""),
        gcs_chroma_prefix=os.getenv("GCS_CHROMA_PREFIX", "yenkasa-ai/chroma"),
        gcs_knowledge_prefix=os.getenv("GCS_KNOWLEDGE_PREFIX", "yenkasa-ai/knowledge"),
        public_bootstrap_dir=bootstrap_dir,
        dev_intelligence_enabled=parse_bool(os.getenv("DEV_INTELLIGENCE_ENABLED"), True),
        mongodb_uri=os.getenv("MONGODB_URI", ""),
        mongodb_database=os.getenv("MONGODB_DATABASE", "yenkasa_ai"),
        mongodb_server_selection_timeout_ms=int(os.getenv("MONGODB_SERVER_SELECTION_TIMEOUT_MS", "3000")),
        mongodb_chunks_collection=os.getenv("MONGODB_CHUNKS_COLLECTION", "repo_chunks"),
        mongodb_jobs_collection=os.getenv("MONGODB_JOBS_COLLECTION", "repo_ingestion_jobs"),
        mongodb_insights_collection=os.getenv("MONGODB_INSIGHTS_COLLECTION", "repo_insights"),
        mongodb_events_collection=os.getenv("MONGODB_EVENTS_COLLECTION", "events"),
        mongodb_users_collection=os.getenv("MONGODB_USERS_COLLECTION", "users"),
        mongodb_sessions_collection=os.getenv("MONGODB_SESSIONS_COLLECTION", "sessions"),
        mongodb_yme_collection=os.getenv("MONGODB_YME_COLLECTION", "yme_events"),
        mongodb_yme_memories_collection=os.getenv("MONGODB_YME_MEMORIES_COLLECTION", "yme_memories"),
        mongodb_yme_graph_collection=os.getenv("MONGODB_YME_GRAPH_COLLECTION", "yme_graph"),
        mongodb_conversations_collection=os.getenv("MONGODB_CONVERSATIONS_COLLECTION", "ai_conversations"),
        mongodb_security_alerts_collection=os.getenv("MONGODB_SECURITY_ALERTS_COLLECTION", "security_alerts"),
        mongodb_logs_collection=os.getenv("MONGODB_LOGS_COLLECTION", "logs"),
        mongodb_log_alerts_collection=os.getenv("MONGODB_LOG_ALERTS_COLLECTION", "log_alerts"),
        mongodb_moderation_alerts_collection=os.getenv("MONGODB_MODERATION_ALERTS_COLLECTION", "moderation_alerts"),
        mongodb_engagement_metrics_collection=os.getenv("MONGODB_ENGAGEMENT_METRICS_COLLECTION", "engagement_metrics"),
        mongodb_ai_insights_collection=os.getenv("MONGODB_AI_INSIGHTS_COLLECTION", "ai_insights"),
        mongodb_github_repositories_collection=os.getenv("MONGODB_GITHUB_REPOSITORIES_COLLECTION", "github_repositories"),
        mongodb_repo_architecture_collection=os.getenv("MONGODB_REPO_ARCHITECTURE_COLLECTION", "repo_architecture"),
        mongodb_vector_index_name=os.getenv("MONGODB_VECTOR_INDEX_NAME", "repo_chunks_vector_index"),
        mongodb_vector_dimensions=int(os.getenv("MONGODB_VECTOR_DIMENSIONS", "768")),
        mongodb_yme_vector_index_name=os.getenv("MONGODB_YME_VECTOR_INDEX_NAME", "yme_memories_vector_index"),
        mongodb_yme_vector_dimensions=int(os.getenv("MONGODB_YME_VECTOR_DIMENSIONS", os.getenv("MONGODB_VECTOR_DIMENSIONS", "768"))),
        redis_url=os.getenv("REDIS_URL", ""),
        upstash_redis_rest_url=os.getenv("UPSTASH_REDIS_REST_URL", ""),
        upstash_redis_rest_token=os.getenv("UPSTASH_REDIS_REST_TOKEN", ""),
        repo_ingestion_queue_name=os.getenv("REPO_INGESTION_QUEUE_NAME", "repo-ingestion"),
        repo_ingestion_job_timeout_s=int(os.getenv("REPO_INGESTION_JOB_TIMEOUT_S", "3600")),
        github_sync_queue_name=os.getenv("GITHUB_SYNC_QUEUE_NAME", "github-sync"),
        github_sync_job_timeout_s=int(os.getenv("GITHUB_SYNC_JOB_TIMEOUT_S", "7200")),
        repo_allowed_roots=parse_paths_csv(os.getenv("REPO_ALLOWED_ROOTS"), default_repo_roots),
        repo_chunk_max_lines=int(os.getenv("REPO_CHUNK_MAX_LINES", "90")),
        repo_chunk_overlap_lines=int(os.getenv("REPO_CHUNK_OVERLAP_LINES", "15")),
        repo_file_size_limit_bytes=int(os.getenv("REPO_FILE_SIZE_LIMIT_BYTES", "1048576")),
        repo_insight_large_file_lines=int(os.getenv("REPO_INSIGHT_LARGE_FILE_LINES", "1200")),
        repo_search_top_k=int(os.getenv("REPO_SEARCH_TOP_K", "6")),
        repo_search_num_candidates=int(os.getenv("REPO_SEARCH_NUM_CANDIDATES", "120")),
        github_token=os.getenv("GITHUB_TOKEN", ""),
        github_owner=os.getenv("GITHUB_OWNER", ""),
        github_scan_all_repos=parse_bool(os.getenv("GITHUB_SCAN_ALL_REPOS"), False),
        github_repo_cache_root=repo_cache_root,
        github_clone_depth=int(os.getenv("GITHUB_CLONE_DEPTH", "1")),
        github_scan_max_files=int(os.getenv("GITHUB_SCAN_MAX_FILES", "4000")),
        github_metadata_cache_ttl_s=int(os.getenv("GITHUB_METADATA_CACHE_TTL_S", "300")),
        github_low_rate_limit_threshold=int(os.getenv("GITHUB_LOW_RATE_LIMIT_THRESHOLD", "250")),
        log_spike_threshold=int(os.getenv("LOG_SPIKE_THRESHOLD", "5")),
        log_spike_multiplier=int(os.getenv("LOG_SPIKE_MULTIPLIER", "2")),
        log_spike_window_minutes=int(os.getenv("LOG_SPIKE_WINDOW_MINUTES", "5")),
        log_stack_window_minutes=int(os.getenv("LOG_STACK_WINDOW_MINUTES", "10")),
        log_stack_repeat_threshold=int(os.getenv("LOG_STACK_REPEAT_THRESHOLD", "3")),
        log_alert_suppression_minutes=int(os.getenv("LOG_ALERT_SUPPRESSION_MINUTES", "10")),
        log_ingest_api_key=os.getenv("LOG_INGEST_API_KEY", ""),
        internal_platform_api_key=os.getenv("INTERNAL_PLATFORM_API_KEY", os.getenv("LOG_INGEST_API_KEY", "")),
        event_ingest_api_key=os.getenv(
            "EVENT_INGEST_API_KEY",
            os.getenv("INTERNAL_PLATFORM_API_KEY", os.getenv("LOG_INGEST_API_KEY", "")),
        ),
        internal_platform_batch_rate_limit=int(os.getenv("INTERNAL_PLATFORM_BATCH_RATE_LIMIT", "240")),
        internal_platform_health_rate_limit=int(os.getenv("INTERNAL_PLATFORM_HEALTH_RATE_LIMIT", "60")),
        event_ingest_rate_limit=int(os.getenv("EVENT_INGEST_RATE_LIMIT", "600")),
        gemini_reasoning_model=os.getenv("GEMINI_REASONING_MODEL", os.getenv("VERTEX_AI_MODEL", "gemini-2.5-flash")),
        gemini_embedding_model=os.getenv("GEMINI_EMBEDDING_MODEL", "text-embedding-005"),
        embedding_batch_size=int(os.getenv("EMBEDDING_BATCH_SIZE", "12")),
        embedding_retry_attempts=int(os.getenv("EMBEDDING_RETRY_ATTEMPTS", "3")),
        jwt_secret_key=os.getenv("JWT_SECRET_KEY", "change-me-in-production"),
        jwt_algorithm=os.getenv("JWT_ALGORITHM", "HS256"),
        access_token_ttl_minutes=int(os.getenv("ACCESS_TOKEN_TTL_MINUTES", "1440")),
        refresh_token_ttl_days=int(os.getenv("REFRESH_TOKEN_TTL_DAYS", "30")),
        auth_window_seconds=int(os.getenv("AUTH_WINDOW_SECONDS", "900")),
        auth_login_rate_limit=int(os.getenv("AUTH_LOGIN_RATE_LIMIT", "12")),
        auth_register_rate_limit=int(os.getenv("AUTH_REGISTER_RATE_LIMIT", "5")),
        ai_request_rate_limit=int(os.getenv("AI_REQUEST_RATE_LIMIT", "120")),
        max_concurrent_sessions=int(os.getenv("MAX_CONCURRENT_SESSIONS", "5")),
        yme_enabled=parse_bool(os.getenv("YME_ENABLED"), True),
        yme_embedding_enabled=parse_bool(os.getenv("YME_EMBEDDING_ENABLED"), True),
        yme_min_importance_score=float(os.getenv("YME_MIN_IMPORTANCE_SCORE", "0.18")),
        yme_memory_search_limit=int(os.getenv("YME_MEMORY_SEARCH_LIMIT", "8")),
        yme_memory_injection_limit=int(os.getenv("YME_MEMORY_INJECTION_LIMIT", "5")),
        yme_memory_context_char_budget=int(os.getenv("YME_MEMORY_CONTEXT_CHAR_BUDGET", "2400")),
        yme_memory_cleanup_days=int(os.getenv("YME_MEMORY_CLEANUP_DAYS", "45")),
    )
