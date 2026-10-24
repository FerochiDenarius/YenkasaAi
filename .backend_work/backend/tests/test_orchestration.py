from __future__ import annotations

import asyncio
from datetime import datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.core.ai_pipeline import ensure_response_shape
from app.core.ai_pipeline import invoke_ai_callable
from app.modules.crl.context_ranker import ConsciousContextRanker
from app.modules.crl.context_retriever import ContextEnvelope
from app.modules.crl.reasoning_pipeline import ConsciousReasoningLayer
from app.modules.repo_search.service import infer_search_mode


def test_invoke_ai_callable_handles_sync_async_and_nested_awaitables():
    async def nested_result():
        return "async result"

    def sync_callable():
        return nested_result()

    async def async_callable():
        return nested_result()

    assert asyncio.run(invoke_ai_callable(sync_callable, label="sync")) == "async result"
    assert asyncio.run(invoke_ai_callable(async_callable, label="async")) == "async result"


def test_ensure_response_shape_rejects_empty_and_invalid_responses():
    with pytest.raises(HTTPException, match="Empty AI response"):
        asyncio.run(ensure_response_shape(None, label="test", required_attr="answer"))

    with pytest.raises(HTTPException, match="Invalid AI response structure"):
        asyncio.run(ensure_response_shape(object(), label="test", required_attr="answer"))

    with pytest.raises(HTTPException, match="Invalid AI response structure"):
        asyncio.run(
            ensure_response_shape(
                SimpleNamespace(answer=123),
                label="test",
                required_attr="answer",
                expected_type=str,
            )
        )


@pytest.mark.parametrize(
    ("question", "mode"),
    [
        ("Explain the architecture flow", "architecture_lookup"),
        ("Where is authentication implemented?", "implementation_trace"),
        ("Find the login logic", "implementation_trace"),
        ("What does this function do?", "semantic_search"),
    ],
)
def test_repo_search_orchestrator_selects_search_mode(question, mode):
    assert infer_search_mode(question) == mode


def test_context_ranker_prioritizes_recent_severe_relevant_operational_evidence():
    ranker = ConsciousContextRanker()
    now = datetime.utcnow()
    alert = ContextEnvelope(
        source="alerts",
        title="deployment failure",
        timestamp=now,
        text="async deployment failed in server.js",
        severity="critical",
    )
    old_info = ContextEnvelope(
        source="conversations",
        title="general chat",
        timestamp=datetime(2020, 1, 1),
        text="unrelated topic",
        severity="info",
    )

    ranked = ranker.rank("What is the current deployment failure?", {"alerts": [alert], "conversations": [old_info]})

    assert ranked[0].envelope is alert
    assert "severity:critical" in ranked[0].reasons
    assert "hotspot" in ranked[0].reasons


def test_conscious_reasoning_layer_injects_relevant_live_context():
    mongo = SimpleNamespace(configured=True)
    layer = ConsciousReasoningLayer(mongo)

    async def retrieve(_question, *, user_id=None):
        return {
            "alerts": [
                ContextEnvelope(
                    source="alerts",
                    title="comment processing failure",
                    timestamp=datetime.utcnow(),
                    text="comment event failed in server.js",
                    severity="error",
                    metadata={"processing_status": "failed", "route": "/events"},
                )
            ]
        }

    layer.retriever.retrieve = retrieve
    context = asyncio.run(layer.build_context("What is happening with comments right now?", user_id="user-1"))

    assert context is not None
    assert context.startswith("CURRENT OPERATIONAL STATE")
    assert "comment processing failure" in context
    assert "Event processing failure detected" in context


def test_conscious_reasoning_layer_skips_non_operational_questions():
    layer = ConsciousReasoningLayer(SimpleNamespace(configured=True))

    assert asyncio.run(layer.build_context("Write a generic welcome message")) is None
