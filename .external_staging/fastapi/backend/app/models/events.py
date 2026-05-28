from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import uuid4

from pydantic import BaseModel
from pydantic import Field


def _event_id() -> str:
    return f"evt_{uuid4().hex}"


class EventDocument(BaseModel):
    event_id: str = Field(default_factory=_event_id)
    event_type: str = Field(min_length=1)
    user_id: str | None = None
    source: str = Field(min_length=1)
    session_id: str | None = None
    request_id: str | None = None
    category: str | None = None
    source_module: str | None = None
    trace_id: str | None = None
    severity: str | None = None
    importance_score: float | None = None
    importance_band: str | None = None
    yme_eligible: bool = False
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    ingested_at: datetime = Field(default_factory=datetime.utcnow)
    processing_status: str = "pending"
    processing_attempts: int = 0
    processors: list[str] = Field(default_factory=list)
    last_processed_at: datetime | None = None
    last_error: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class ModerationAlertDocument(BaseModel):
    alert_id: str = Field(default_factory=lambda: f"mal_{uuid4().hex}")
    event_id: str
    event_type: str
    source: str
    status: str = "open"
    severity: str = "medium"
    user_id: str | None = None
    target_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class EngagementMetricDocument(BaseModel):
    metric_id: str = Field(default_factory=lambda: f"met_{uuid4().hex}")
    source: str
    event_type: str
    bucket_start: datetime
    bucket_granularity: str = "hour"
    total_count: int = 0
    metadata: dict[str, Any] = Field(default_factory=dict)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class AIInsightDocument(BaseModel):
    insight_id: str = Field(default_factory=lambda: f"ins_{uuid4().hex}")
    insight_type: str
    status: str = "open"
    source: str
    event_id: str
    event_type: str
    summary: str
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
