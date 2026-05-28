from __future__ import annotations

from copy import deepcopy
from datetime import datetime
from types import SimpleNamespace
import unittest

from app.modules.events.service import EventService
from app.schemas import EventRequest


class _FakeCollection:
    def __init__(self) -> None:
        self.rows: list[dict] = []

    async def insert_one(self, document: dict) -> None:
        self.rows.append(deepcopy(document))

    async def insert_many(self, documents: list[dict], ordered: bool = False) -> None:
        _ = ordered
        for document in documents:
            self.rows.append(deepcopy(document))

    async def update_one(self, query: dict, update: dict, upsert: bool = False) -> None:
        _ = upsert
        for row in self.rows:
            if all(row.get(key) == value for key, value in query.items()):
                self._apply_update(row, update)
                return

        new_row = dict(query)
        self._apply_update(new_row, update, created=True)
        self.rows.append(new_row)

    def _apply_update(self, row: dict, update: dict, created: bool = False) -> None:
        if "$set" in update:
            for key, value in update["$set"].items():
                row[key] = deepcopy(value)
        if "$inc" in update:
            for key, value in update["$inc"].items():
                row[key] = row.get(key, 0) + value
        if created and "$setOnInsert" in update:
            for key, value in update["$setOnInsert"].items():
                row.setdefault(key, deepcopy(value))


class _FakeSecurity:
    def __init__(self) -> None:
        self.alerts: list[dict] = []

    async def record_alert(self, **kwargs) -> None:
        self.alerts.append(kwargs)


class _FakeMongo:
    def __init__(self) -> None:
        self.events_collection = _FakeCollection()
        self.moderation_alerts_collection = _FakeCollection()
        self.engagement_metrics_collection = _FakeCollection()
        self.ai_insights_collection = _FakeCollection()


class EventPipelineTests(unittest.IsolatedAsyncioTestCase):
    async def test_process_event_writes_moderation_security_and_engagement_records(self) -> None:
        mongo = _FakeMongo()
        security = _FakeSecurity()
        service = EventService(SimpleNamespace(), mongo, yme_service=None, security_service=security)

        moderation_payload = EventRequest.model_validate(
            {
                "eventType": "moderation_report_created",
                "source": "yenkasa_app",
                "userId": "user-123",
                "metadata": {"postId": "post-1", "reason": "spam"},
                "timestamp": datetime.utcnow().isoformat(),
            }
        )
        moderation_event = await service.record_event(moderation_payload, capture_memory=False)
        moderation_result = await service.process_event_document(moderation_event.model_dump(mode="python"))

        self.assertEqual(moderation_result["status"], "processed")
        self.assertIn("moderation", moderation_result["processors"])
        self.assertEqual(len(mongo.moderation_alerts_collection.rows), 1)
        self.assertEqual(len(mongo.ai_insights_collection.rows), 1)

        security_payload = EventRequest.model_validate(
            {
                "eventType": "login_attempt",
                "source": "yenkasa_app",
                "userId": "user-123",
                "metadata": {"status": "failed", "ip": "127.0.0.1"},
            }
        )
        security_event = await service.record_event(security_payload, capture_memory=False)
        security_result = await service.process_event_document(security_event.model_dump(mode="python"))

        self.assertIn("security", security_result["processors"])
        self.assertEqual(len(security.alerts), 1)

        engagement_payload = EventRequest.model_validate(
            {
                "eventType": "post_view",
                "source": "yenkasa_app",
                "userId": "user-123",
                "metadata": {"postId": "post-1"},
            }
        )
        engagement_event = await service.record_event(engagement_payload, capture_memory=False)
        engagement_result = await service.process_event_document(engagement_event.model_dump(mode="python"))

        self.assertIn("engagement", engagement_result["processors"])
        self.assertEqual(len(mongo.engagement_metrics_collection.rows), 1)
        self.assertEqual(mongo.events_collection.rows[-1]["processing_status"], "processed")


if __name__ == "__main__":
    unittest.main()
