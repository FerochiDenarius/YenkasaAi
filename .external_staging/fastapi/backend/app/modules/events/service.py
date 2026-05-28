from __future__ import annotations

from collections import Counter
from datetime import datetime
from datetime import timedelta
import logging
from typing import Any

from app.models import AIInsightDocument
from app.models import EngagementMetricDocument
from app.models import EventDocument
from app.models import ModerationAlertDocument


LOGGER = logging.getLogger("yenkasa_ai_cloud.events")

# TODO(kafka-migration): Move event processing fan-out from in-process background tasks to a dedicated stream
# consumer once cross-service throughput and replay requirements justify it.

EVENT_CATEGORY_MAP = {
    "post_created": "engagement",
    "post_view": "engagement",
    "video_watch": "engagement",
    "comment_created": "engagement",
    "message_sent": "engagement",
    "report_created": "moderation",
    "moderation_flagged": "moderation",
    "moderation_report_created": "moderation",
    "moderation_post_reviewed": "moderation",
    "moderation_user_reported": "moderation",
    "moderation_post_hidden": "moderation",
    "suspicious_activity": "security",
    "login_attempt": "security",
    "order_created": "commerce",
    "payment_verified": "commerce",
    "seller_registered": "commerce",
    "product_uploaded": "commerce",
}

ENGAGEMENT_EVENT_TYPES = {
    "post_created",
    "post_view",
    "video_watch",
    "comment_created",
    "message_sent",
    "order_created",
    "payment_verified",
    "seller_registered",
    "product_uploaded",
}

MODERATION_EVENT_TYPES = {
    "report_created",
    "moderation_flagged",
    "moderation_report_created",
    "moderation_post_reviewed",
    "moderation_user_reported",
    "moderation_post_hidden",
}

SECURITY_EVENT_TYPES = {
    "login_attempt",
    "suspicious_activity",
}


class EventService:
    def __init__(self, settings, mongo_service, yme_service=None, security_service=None) -> None:
        self.settings = settings
        self.mongo = mongo_service
        self.yme = yme_service
        self.security = security_service

    def _resolve_category(self, payload) -> str | None:
        if getattr(payload, "category", None):
            return payload.category
        return EVENT_CATEGORY_MAP.get(str(payload.event_type))

    def _build_event_document(self, payload) -> EventDocument:
        return EventDocument(
            event_type=str(payload.event_type),
            user_id=payload.user_id,
            source=payload.source,
            session_id=getattr(payload, "session_id", None),
            request_id=getattr(payload, "request_id", None),
            category=self._resolve_category(payload),
            source_module=getattr(payload, "source_module", None),
            trace_id=getattr(payload, "trace_id", None),
            severity=getattr(payload, "severity", None),
            importance_score=getattr(payload, "importance_score", None),
            importance_band=getattr(payload, "importance_band", None),
            yme_eligible=bool(getattr(payload, "yme_eligible", False)),
            timestamp=payload.timestamp or datetime.utcnow(),
            metadata=payload.metadata,
        )

    async def _capture_yme_memory(self, payload) -> int:
        if self.yme is None or not payload.user_id or not bool(getattr(payload, "yme_eligible", False)):
            return 0

        try:
            stored = await self.yme.remember_event_payload(payload)
        except Exception:
            LOGGER.exception("YME event memory capture failed for event_type=%s", payload.event_type)
            return 0

        return len(stored or [])

    async def record_event(self, payload, *, capture_memory: bool = True) -> EventDocument:
        event = self._build_event_document(payload)
        await self.mongo.events_collection.insert_one(event.model_dump(mode="json"))
        if capture_memory:
            await self._capture_yme_memory(payload)
        return event

    async def record_events_batch(self, payloads) -> dict:
        documents = [self._build_event_document(payload) for payload in payloads]
        if not documents:
            return {
                "stored_count": 0,
                "yme_memory_count": 0,
                "stored_at": datetime.utcnow(),
                "detected_patterns": [],
                "operational_summary": {},
            }

        await self.mongo.events_collection.insert_many(
            [document.model_dump(mode="json") for document in documents],
            ordered=False,
        )

        yme_memory_count = 0
        for payload in payloads:
            yme_memory_count += await self._capture_yme_memory(payload)

        analysis = await self.detect_batch_patterns(payloads)
        return {
            "stored_count": len(documents),
            "yme_memory_count": yme_memory_count,
            "stored_at": datetime.utcnow(),
            "detected_patterns": analysis["detected_patterns"],
            "operational_summary": analysis["operational_summary"],
        }

    async def _mark_processing_state(
        self,
        event_id: str,
        *,
        status: str,
        processors: list[str] | None = None,
        error: str | None = None,
    ) -> None:
        update: dict[str, Any] = {
            "$set": {
                "processing_status": status,
                "last_processed_at": datetime.utcnow(),
                "last_error": error,
            },
            "$inc": {"processing_attempts": 1},
        }
        if processors is not None:
            update["$set"]["processors"] = processors
        await self.mongo.events_collection.update_one({"event_id": event_id}, update)

    def _event_target_id(self, event: EventDocument) -> str | None:
        for key in ("postId", "messageId", "commentId", "orderId", "productId", "sellerId", "targetId"):
            value = event.metadata.get(key)
            if value:
                return str(value)
        return None

    async def _record_moderation_alert(self, event: EventDocument) -> None:
        alert = ModerationAlertDocument(
            event_id=event.event_id,
            event_type=event.event_type,
            source=event.source,
            user_id=event.user_id,
            target_id=self._event_target_id(event),
            metadata=event.metadata,
        )
        await self.mongo.moderation_alerts_collection.update_one(
            {"event_id": event.event_id},
            {"$setOnInsert": alert.model_dump(mode="json")},
            upsert=True,
        )

    async def _record_security_alert(self, event: EventDocument) -> None:
        outcome = str(event.metadata.get("status") or event.metadata.get("outcome") or "").lower()
        if event.event_type == "login_attempt" and outcome == "success":
            return

        if self.security is None:
            return

        severity = "high" if event.event_type == "suspicious_activity" else "medium"
        await self.security.record_alert(
            alert_type=event.event_type,
            severity=severity,
            user_id=event.user_id,
            session_id=event.session_id,
            ip_address=str(event.metadata.get("ip") or event.metadata.get("ipAddress") or "") or None,
            metadata={
                **event.metadata,
                "event_id": event.event_id,
                "event_type": event.event_type,
                "source": event.source,
            },
        )

    async def _update_engagement_metric(self, event: EventDocument) -> None:
        bucket_start = event.timestamp.replace(minute=0, second=0, microsecond=0)
        metric = EngagementMetricDocument(
            source=event.source,
            event_type=event.event_type,
            bucket_start=bucket_start,
            total_count=1,
            metadata={
                "last_user_id": event.user_id,
                "last_target_id": self._event_target_id(event),
            },
        )
        await self.mongo.engagement_metrics_collection.update_one(
            {
                "source": event.source,
                "event_type": event.event_type,
                "bucket_start": bucket_start,
            },
            {
                "$inc": {"total_count": 1},
                "$set": {
                    "updated_at": datetime.utcnow(),
                    "metadata.last_user_id": event.user_id,
                    "metadata.last_target_id": self._event_target_id(event),
                },
                "$setOnInsert": metric.model_dump(mode="json"),
            },
            upsert=True,
        )

    async def _record_observability_insight(self, event: EventDocument, processors: list[str]) -> None:
        if not processors:
            return

        insight = AIInsightDocument(
            insight_type=f"{event.category or 'operational'}_signal",
            source=event.source,
            event_id=event.event_id,
            event_type=event.event_type,
            summary=f"{event.event_type} processed through {', '.join(processors)} pipeline(s).",
            metadata={
                "processors": processors,
                "target_id": self._event_target_id(event),
                "status": event.metadata.get("status") or event.metadata.get("outcome"),
            },
        )
        await self.mongo.ai_insights_collection.insert_one(insight.model_dump(mode="json"))

    async def process_event_document(self, document: EventDocument | dict[str, Any]) -> dict[str, Any]:
        event = document if isinstance(document, EventDocument) else EventDocument.model_validate(document)
        processors: list[str] = []
        await self._mark_processing_state(event.event_id, status="processing", processors=processors)

        try:
            if event.event_type in MODERATION_EVENT_TYPES:
                await self._record_moderation_alert(event)
                processors.append("moderation")

            if event.event_type in SECURITY_EVENT_TYPES:
                await self._record_security_alert(event)
                processors.append("security")

            if event.event_type in ENGAGEMENT_EVENT_TYPES:
                await self._update_engagement_metric(event)
                processors.append("engagement")

            if self.yme is not None and event.user_id and event.yme_eligible:
                await self._capture_yme_memory(event)
                processors.append("memory")

            await self._record_observability_insight(event, processors)
            processors.append("observability")
            await self._mark_processing_state(event.event_id, status="processed", processors=processors)
            return {
                "event_id": event.event_id,
                "processors": processors,
                "status": "processed",
            }
        except Exception as exc:
            LOGGER.exception("Event processing failed event_id=%s event_type=%s", event.event_id, event.event_type)
            await self._mark_processing_state(
                event.event_id,
                status="failed",
                processors=processors,
                error=str(exc),
            )
            raise

    async def detect_batch_patterns(self, payloads) -> dict:
        if not payloads:
            return {
                "detected_patterns": [],
                "operational_summary": {},
            }

        detected_patterns: set[str] = set()
        category_counts = Counter(str(getattr(payload, "category", "") or "") for payload in payloads)
        event_name_counts = Counter(str(getattr(payload, "event_type", "") or "") for payload in payloads)
        error_payloads = [
            payload
            for payload in payloads
            if str(getattr(payload, "severity", "")).lower() in {"error", "critical"}
            or str(getattr(payload, "category", "")).lower() in {"system_error", "api_failure", "upload_failure"}
        ]

        repeated_crashes = await self._repeated_crashes(error_payloads)
        if repeated_crashes:
            detected_patterns.add("repeated_crash_detection")

        auth_anomalies = await self._auth_anomalies(payloads)
        if auth_anomalies:
            detected_patterns.add("auth_anomaly_detection")

        upload_failures = await self._upload_failure_spikes(payloads)
        if upload_failures:
            detected_patterns.add("upload_failure_spike")

        api_degradation = await self._api_degradation(payloads)
        if api_degradation:
            detected_patterns.add("api_degradation_detection")

        suspicious_engagement = await self._suspicious_engagement(payloads)
        if suspicious_engagement:
            detected_patterns.add("suspicious_engagement_farming")

        return {
            "detected_patterns": sorted(detected_patterns),
            "operational_summary": {
                "batch_size": len(payloads),
                "category_counts": dict(category_counts),
                "event_name_counts": dict(event_name_counts),
                "repeated_crashes": repeated_crashes,
                "auth_anomalies": auth_anomalies,
                "upload_failure_spikes": upload_failures,
                "api_degradation": api_degradation,
                "suspicious_engagement": suspicious_engagement,
            },
        }

    async def summarize_platform_health(self, window_minutes: int = 60) -> dict:
        now = datetime.utcnow()
        since = now - timedelta(minutes=max(1, int(window_minutes)))

        repeated_crashes = [
            row
            async for row in self.mongo.events_collection.aggregate(
                [
                    {
                        "$match": {
                            "timestamp": {"$gte": since},
                            "severity": {"$in": ["error", "critical"]},
                        }
                    },
                    {
                        "$group": {
                            "_id": {
                                "event_type": "$event_type",
                                "source_module": "$source_module",
                            },
                            "count": {"$sum": 1},
                            "latest_at": {"$max": "$timestamp"},
                        }
                    },
                    {"$match": {"count": {"$gte": 3}}},
                    {"$sort": {"count": -1, "latest_at": -1}},
                    {"$limit": 10},
                ]
            )
        ]

        api_degradation = [
            row
            async for row in self.mongo.events_collection.aggregate(
                [
                    {
                        "$match": {
                            "timestamp": {"$gte": since},
                            "category": {"$in": ["api_failure", "analytics_event"]},
                            "metadata.latency_ms": {"$exists": True},
                        }
                    },
                    {
                        "$group": {
                            "_id": "$metadata.route_path",
                            "count": {"$sum": 1},
                            "avg_latency_ms": {"$avg": "$metadata.latency_ms"},
                            "max_latency_ms": {"$max": "$metadata.latency_ms"},
                        }
                    },
                    {
                        "$match": {
                            "$or": [
                                {"count": {"$gte": 5}},
                                {"avg_latency_ms": {"$gte": 2500}},
                                {"max_latency_ms": {"$gte": 5000}},
                            ]
                        }
                    },
                    {"$sort": {"avg_latency_ms": -1, "count": -1}},
                    {"$limit": 10},
                ]
            )
        ]

        auth_anomalies = [
            row
            async for row in self.mongo.events_collection.aggregate(
                [
                    {
                        "$match": {
                            "timestamp": {"$gte": since},
                            "$or": [
                                {"category": "auth_event"},
                                {"event_type": "login_attempt"},
                                {"event_type": "suspicious_activity"},
                            ],
                        }
                    },
                    {
                        "$group": {
                            "_id": {
                                "user_id": "$user_id",
                                "ip": "$metadata.ip",
                            },
                            "count": {"$sum": 1},
                            "latest_at": {"$max": "$timestamp"},
                        }
                    },
                    {"$match": {"count": {"$gte": 5}}},
                    {"$sort": {"count": -1, "latest_at": -1}},
                    {"$limit": 10},
                ]
            )
        ]

        upload_failure_spikes = [
            row
            async for row in self.mongo.events_collection.aggregate(
                [
                    {
                        "$match": {
                            "timestamp": {"$gte": since},
                            "category": "upload_failure",
                        }
                    },
                    {
                        "$group": {
                            "_id": "$source_module",
                            "count": {"$sum": 1},
                            "latest_at": {"$max": "$timestamp"},
                        }
                    },
                    {"$match": {"count": {"$gte": 3}}},
                    {"$sort": {"count": -1, "latest_at": -1}},
                    {"$limit": 10},
                ]
            )
        ]

        suspicious_engagement = [
            row
            async for row in self.mongo.events_collection.aggregate(
                [
                    {
                        "$match": {
                            "timestamp": {"$gte": since},
                            "category": {"$in": ["engagement", "payment_event"]},
                            "user_id": {"$nin": [None, ""]},
                        }
                    },
                    {
                        "$group": {
                            "_id": "$user_id",
                            "count": {"$sum": 1},
                            "reward_events": {
                                "$sum": {
                                    "$cond": [
                                        {
                                            "$regexMatch": {
                                                "input": "$event_type",
                                                "regex": "(reward|ad_.*reward|monetization)",
                                                "options": "i",
                                            }
                                        },
                                        1,
                                        0,
                                    ]
                                }
                            },
                            "latest_at": {"$max": "$timestamp"},
                        }
                    },
                    {
                        "$match": {
                            "$or": [
                                {"count": {"$gte": 25}},
                                {"reward_events": {"$gte": 5}},
                            ]
                        }
                    },
                    {"$sort": {"count": -1, "reward_events": -1}},
                    {"$limit": 10},
                ]
            )
        ]

        return {
            "window_minutes": max(1, int(window_minutes)),
            "repeated_crashes": repeated_crashes,
            "auth_anomalies": auth_anomalies,
            "upload_failure_spikes": upload_failure_spikes,
            "api_degradation": api_degradation,
            "suspicious_engagement": suspicious_engagement,
        }

    async def _repeated_crashes(self, payloads) -> list[dict]:
        if not payloads:
            return []

        results: list[dict] = []
        now = datetime.utcnow()
        window_start = now - timedelta(minutes=60)
        seen: set[tuple[str, str]] = set()
        for payload in payloads:
            category = str(getattr(payload, "category", "")).lower()
            severity = str(getattr(payload, "severity", "")).lower()
            if category not in {"system_error", "api_failure", "upload_failure"} and severity not in {
                "error",
                "critical",
            }:
                continue

            event_type = str(getattr(payload, "event_type", "") or "")
            source_module = str(getattr(payload, "source_module", "") or "")
            key = (event_type, source_module)
            if key in seen:
                continue
            seen.add(key)

            count = await self.mongo.events_collection.count_documents(
                {
                    "timestamp": {"$gte": window_start},
                    "event_type": event_type,
                    "source_module": source_module,
                    "severity": {"$in": ["error", "critical"]},
                }
            )
            if count >= 3:
                results.append(
                    {
                        "event_type": event_type,
                        "source_module": source_module,
                        "count": count,
                    }
                )
        return results

    async def _auth_anomalies(self, payloads) -> list[dict]:
        auth_payloads = [payload for payload in payloads if str(getattr(payload, "category", "")).lower() == "auth_event"]
        if not auth_payloads:
            return []

        results: list[dict] = []
        now = datetime.utcnow()
        window_start = now - timedelta(minutes=30)
        seen_keys: set[tuple[str, str]] = set()
        for payload in auth_payloads:
            user_id = str(getattr(payload, "user_id", "") or "")
            metadata = getattr(payload, "metadata", {}) or {}
            ip = str(metadata.get("ip", "") or "")
            key = (user_id, ip)
            if key in seen_keys:
                continue
            seen_keys.add(key)
            query = {
                "timestamp": {"$gte": window_start},
                "category": "auth_event",
            }
            if user_id:
                query["user_id"] = user_id
            if ip:
                query["metadata.ip"] = ip
            count = await self.mongo.events_collection.count_documents(query)
            if count >= 5:
                results.append(
                    {
                        "user_id": user_id or None,
                        "ip": ip or None,
                        "count": count,
                    }
                )
        return results

    async def _upload_failure_spikes(self, payloads) -> list[dict]:
        relevant = [
            payload for payload in payloads if str(getattr(payload, "category", "")).lower() == "upload_failure"
        ]
        if not relevant:
            return []

        results: list[dict] = []
        now = datetime.utcnow()
        window_start = now - timedelta(minutes=30)
        seen_modules: set[str] = set()
        for payload in relevant:
            source_module = str(getattr(payload, "source_module", "") or "")
            if source_module in seen_modules:
                continue
            seen_modules.add(source_module)
            count = await self.mongo.events_collection.count_documents(
                {
                    "timestamp": {"$gte": window_start},
                    "category": "upload_failure",
                    "source_module": source_module,
                }
            )
            if count >= 3:
                results.append(
                    {
                        "source_module": source_module or None,
                        "count": count,
                    }
                )
        return results

    async def _api_degradation(self, payloads) -> list[dict]:
        relevant = [
            payload
            for payload in payloads
            if str(getattr(payload, "category", "")).lower() in {"api_failure", "analytics_event"}
            and isinstance(getattr(payload, "metadata", {}), dict)
            and getattr(payload, "metadata", {}).get("route_path")
        ]
        if not relevant:
            return []

        results: list[dict] = []
        now = datetime.utcnow()
        window_start = now - timedelta(minutes=30)
        seen_routes: set[str] = set()
        for payload in relevant:
            route_path = str((getattr(payload, "metadata", {}) or {}).get("route_path", "") or "")
            if not route_path or route_path in seen_routes:
                continue
            seen_routes.add(route_path)
            rows = [
                row
                async for row in self.mongo.events_collection.aggregate(
                    [
                        {
                            "$match": {
                                "timestamp": {"$gte": window_start},
                                "metadata.route_path": route_path,
                                "metadata.latency_ms": {"$exists": True},
                            }
                        },
                        {
                            "$group": {
                                "_id": "$metadata.route_path",
                                "count": {"$sum": 1},
                                "avg_latency_ms": {"$avg": "$metadata.latency_ms"},
                                "max_latency_ms": {"$max": "$metadata.latency_ms"},
                            }
                        },
                    ]
                )
            ]
            if not rows:
                continue
            row = rows[0]
            if row["count"] >= 5 or row["avg_latency_ms"] >= 2500 or row["max_latency_ms"] >= 5000:
                results.append(
                    {
                        "route_path": route_path,
                        "count": row["count"],
                        "avg_latency_ms": row["avg_latency_ms"],
                        "max_latency_ms": row["max_latency_ms"],
                    }
                )
        return results

    async def _suspicious_engagement(self, payloads) -> list[dict]:
        relevant = [
            payload
            for payload in payloads
            if str(getattr(payload, "category", "")).lower() in {"engagement", "payment_event"}
            and str(getattr(payload, "user_id", "") or "")
        ]
        if not relevant:
            return []

        results: list[dict] = []
        now = datetime.utcnow()
        window_start = now - timedelta(minutes=30)
        seen_users: set[str] = set()
        for payload in relevant:
            user_id = str(getattr(payload, "user_id", "") or "")
            if not user_id or user_id in seen_users:
                continue
            seen_users.add(user_id)
            rows = [
                row
                async for row in self.mongo.events_collection.aggregate(
                    [
                        {
                            "$match": {
                                "timestamp": {"$gte": window_start},
                                "user_id": user_id,
                                "category": {"$in": ["engagement", "payment_event"]},
                            }
                        },
                        {
                            "$group": {
                                "_id": "$user_id",
                                "count": {"$sum": 1},
                                "reward_events": {
                                    "$sum": {
                                        "$cond": [
                                            {
                                                "$regexMatch": {
                                                    "input": "$event_type",
                                                    "regex": "(reward|ad_.*reward|monetization)",
                                                    "options": "i",
                                                }
                                            },
                                            1,
                                            0,
                                        ]
                                    }
                                },
                            }
                        },
                    ]
                )
            ]
            if not rows:
                continue
            row = rows[0]
            if row["count"] >= 25 or row["reward_events"] >= 5:
                results.append(
                    {
                        "user_id": user_id,
                        "count": row["count"],
                        "reward_events": row["reward_events"],
                    }
                )
        return results
