from __future__ import annotations

from datetime import datetime

import pytest
from pydantic import ValidationError

from app.models import ChatRequest
from app.models import SearchRequest
from app.schemas import AuthLoginRequest
from app.schemas import AuthRefreshRequest
from app.schemas import AuthRegisterRequest
from app.schemas import EventRequest
from app.schemas import RepoChatRequest
from app.schemas import RepoIngestionRequest


@pytest.mark.parametrize(
    ("model", "payload", "field"),
    [
        (AuthRegisterRequest, {"username": "ab", "email": "a@b.com", "password": "short"}, "username"),
        (AuthLoginRequest, {"email": "a@b.com", "password": "short"}, "password"),
        (AuthRefreshRequest, {"refresh_token": "too-short"}, "refresh_token"),
        (RepoIngestionRequest, {"repo_path": ""}, "repo_path"),
        (RepoChatRequest, {"question": "", "top_k": 1}, "question"),
        (EventRequest, {"event_type": "", "user_id": "u", "app_source": "web"}, "event_type"),
        (ChatRequest, {"question": "", "audience": "public"}, "question"),
        (SearchRequest, {"question": "", "audience": "public"}, "question"),
    ],
)
def test_pydantic_models_reject_invalid_required_values(model, payload, field):
    with pytest.raises(ValidationError) as error:
        model(**payload)

    assert field in str(error.value)


def test_registration_defaults_and_literal_validation():
    request = AuthRegisterRequest(username="developer", email="dev@example.com", password="password123")

    assert request.agree_to_terms is False
    assert request.preferences == {}
    assert request.metadata == {}

    with pytest.raises(ValidationError):
        AuthRegisterRequest(
            username="developer",
            email="dev@example.com",
            password="password123",
            signup_type="unsupported",
        )


@pytest.mark.parametrize("top_k", [0, 21])
def test_repository_chat_top_k_is_bounded(top_k):
    with pytest.raises(ValidationError):
        RepoChatRequest(question="find auth", top_k=top_k)


def test_datetime_and_metadata_are_preserved():
    timestamp = datetime(2026, 1, 1, 12, 0, 0)
    event = EventRequest(
        event_type="login",
        user_id="user-1",
        app_source="web",
        timestamp=timestamp,
        metadata={"ip": "127.0.0.1"},
    )

    assert event.timestamp == timestamp
    assert event.metadata == {"ip": "127.0.0.1"}
