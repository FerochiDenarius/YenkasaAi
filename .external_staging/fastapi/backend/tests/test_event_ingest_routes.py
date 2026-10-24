from __future__ import annotations

import unittest
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.intelligence_routes import router
from app.core.dependencies import get_intelligence_runtime
from app.models import EventDocument


class _FakeSecurity:
    async def enforce_rate_limit(self, **_kwargs) -> None:
        return None


class _FakeEvents:
    def __init__(self) -> None:
        self.recorded: list[tuple[object, bool]] = []
        self.processed: list[object] = []

    async def record_event(self, payload, *, capture_memory: bool = True) -> EventDocument:
        self.recorded.append((payload, capture_memory))
        return EventDocument(
            event_type=str(payload.event_type),
            source=payload.source,
            user_id=payload.user_id,
            metadata=payload.metadata,
        )

    async def process_event_document(self, document) -> None:
        self.processed.append(document)


class EventIngestRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fake_events = _FakeEvents()
        fake_runtime = SimpleNamespace(
            settings=SimpleNamespace(
                event_ingest_api_key="test-event-key",
                internal_platform_api_key="",
                event_ingest_rate_limit=100,
            ),
            security=_FakeSecurity(),
            events=self.fake_events,
        )
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_intelligence_runtime] = lambda: fake_runtime
        self.client = TestClient(app)

    def test_ingest_event_accepts_api_key_and_camel_case_payload(self) -> None:
        response = self.client.post(
            "/api/events/ingest",
            headers={"X-Event-Api-Key": "test-event-key"},
            json={
                "eventType": "post_created",
                "source": "yenkasa_app",
                "userId": "user-123",
                "metadata": {"postId": "post-1"},
            },
        )

        self.assertEqual(response.status_code, 202)
        payload = response.json()
        self.assertEqual(payload["status"], "accepted")
        self.assertEqual(payload["eventType"], "post_created")
        self.assertEqual(payload["source"], "yenkasa_app")
        self.assertEqual(len(self.fake_events.recorded), 1)
        self.assertFalse(self.fake_events.recorded[0][1])

    def test_ingest_event_rejects_missing_credentials(self) -> None:
        response = self.client.post(
            "/api/events/ingest",
            json={
                "eventType": "post_created",
                "source": "yenkasa_app",
                "metadata": {"postId": "post-1"},
            },
        )

        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
