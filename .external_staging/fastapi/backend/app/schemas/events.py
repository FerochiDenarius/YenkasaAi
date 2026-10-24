from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import Any

from pydantic import AliasChoices
from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import field_validator


class EventType(StrEnum):
    POST_CREATED = "post_created"
    POST_VIEW = "post_view"
    VIDEO_WATCH = "video_watch"
    COMMENT_CREATED = "comment_created"
    MESSAGE_SENT = "message_sent"
    REPORT_CREATED = "report_created"
    SUSPICIOUS_ACTIVITY = "suspicious_activity"
    LOGIN_ATTEMPT = "login_attempt"
    ORDER_CREATED = "order_created"
    PAYMENT_VERIFIED = "payment_verified"
    SELLER_REGISTERED = "seller_registered"
    PRODUCT_UPLOADED = "product_uploaded"
    MODERATION_FLAGGED = "moderation_flagged"
    MODERATION_REPORT_CREATED = "moderation_report_created"
    MODERATION_POST_REVIEWED = "moderation_post_reviewed"
    MODERATION_USER_REPORTED = "moderation_user_reported"
    MODERATION_POST_HIDDEN = "moderation_post_hidden"


class EventRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    event_type: EventType = Field(validation_alias=AliasChoices("eventType", "event_type"))
    source: str = Field(min_length=1, validation_alias=AliasChoices("source", "app_source"))
    user_id: str | None = Field(default=None, validation_alias=AliasChoices("userId", "user_id"))
    session_id: str | None = Field(default=None, validation_alias=AliasChoices("sessionId", "session_id"))
    request_id: str | None = Field(default=None, validation_alias=AliasChoices("requestId", "request_id"))
    category: str | None = None
    source_module: str | None = Field(default=None, validation_alias=AliasChoices("sourceModule", "source_module"))
    trace_id: str | None = Field(default=None, validation_alias=AliasChoices("traceId", "trace_id"))
    severity: str | None = None
    importance_score: float | None = None
    importance_band: str | None = None
    yme_eligible: bool = Field(default=False, validation_alias=AliasChoices("ymeEligible", "yme_eligible"))
    timestamp: datetime | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("source", mode="before")
    @classmethod
    def _normalize_source(cls, value: str) -> str:
        return str(value or "").strip().lower().replace(" ", "_")

    @field_validator("user_id", "session_id", "request_id", "source_module", "trace_id", mode="before")
    @classmethod
    def _trim_optional_strings(cls, value: str | None) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None


class EventIngestResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: str
    event_id: str = Field(serialization_alias="eventId")
    event_type: str = Field(serialization_alias="eventType")
    source: str
    queued_for_processing: bool = Field(serialization_alias="queuedForProcessing")
    processing_status: str = Field(serialization_alias="processingStatus")
    stored_at: datetime


class EventBatchRequest(BaseModel):
    source: str = Field(default="yenkasa_app_backend", min_length=1)
    events: list[EventRequest] = Field(default_factory=list)


class EventBatchIngestResponse(BaseModel):
    status: str
    accepted_count: int = 0
    stored_count: int = 0
    yme_memory_count: int = 0
    detected_patterns: list[str] = Field(default_factory=list)
    operational_summary: dict[str, Any] = Field(default_factory=dict)
    source: str
    stored_at: datetime
