from __future__ import annotations

import asyncio
import logging

from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ASCENDING
from pymongo import MongoClient


LOGGER = logging.getLogger("yenkasa_ai_cloud.mongo")


class MongoService:
    def __init__(self, settings) -> None:
        self.settings = settings
        self.async_client: AsyncIOMotorClient | None = None
        self.sync_client: MongoClient | None = None
        self.database = None
        self.sync_database = None

    @property
    def configured(self) -> bool:
        return bool(self.settings.mongodb_uri and self.settings.mongodb_database)

    @property
    def chunks_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_chunks_collection]

    @property
    def jobs_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_jobs_collection]

    @property
    def insights_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_insights_collection]

    @property
    def users_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_users_collection]

    @property
    def sessions_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_sessions_collection]

    @property
    def yme_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_yme_collection]

    @property
    def yme_memories_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_yme_memories_collection]

    @property
    def yme_graph_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_yme_graph_collection]

    @property
    def conversations_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_conversations_collection]

    @property
    def security_alerts_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_security_alerts_collection]

    @property
    def logs_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_logs_collection]

    @property
    def log_alerts_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_log_alerts_collection]

    @property
    def moderation_alerts_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_moderation_alerts_collection]

    @property
    def engagement_metrics_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_engagement_metrics_collection]

    @property
    def ai_insights_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_ai_insights_collection]

    @property
    def github_repositories_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_github_repositories_collection]

    @property
    def repo_architecture_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_repo_architecture_collection]

    @property
    def events_collection(self):
        if self.database is None:
            raise RuntimeError("MongoDB is not connected.")
        return self.database[self.settings.mongodb_events_collection]

    @property
    def sync_chunks_collection(self):
        if self.sync_database is None:
            raise RuntimeError("MongoDB sync client is not connected.")
        return self.sync_database[self.settings.mongodb_chunks_collection]

    @property
    def sync_yme_memories_collection(self):
        if self.sync_database is None:
            raise RuntimeError("MongoDB sync client is not connected.")
        return self.sync_database[self.settings.mongodb_yme_memories_collection]

    async def connect(self) -> None:
        if not self.configured:
            LOGGER.warning("MongoDB not configured; dev intelligence data APIs will stay degraded.")
            return

        self.async_client = AsyncIOMotorClient(
            self.settings.mongodb_uri,
            serverSelectionTimeoutMS=self.settings.mongodb_server_selection_timeout_ms,
        )
        self.sync_client = MongoClient(
            self.settings.mongodb_uri,
            serverSelectionTimeoutMS=self.settings.mongodb_server_selection_timeout_ms,
        )
        self.database = self.async_client[self.settings.mongodb_database]
        self.sync_database = self.sync_client[self.settings.mongodb_database]
        await self.ping()
        await self.ensure_indexes()
        LOGGER.info("MongoDB ready database=%s", self.settings.mongodb_database)

    async def ensure_indexes(self) -> None:
        if self.database is None:
            return

        await self.jobs_collection.create_index([("job_id", ASCENDING)], unique=True)
        await self.jobs_collection.create_index([("repo_name", ASCENDING), ("status", ASCENDING)])
        await self.chunks_collection.create_index(
            [("repo_name", ASCENDING), ("file_path", ASCENDING), ("chunk_index", ASCENDING)],
            unique=True,
        )
        await self.chunks_collection.create_index([("repo_name", ASCENDING), ("hash", ASCENDING)])
        await self.chunks_collection.create_index([("repo_name", ASCENDING), ("language", ASCENDING)])
        await self.insights_collection.create_index([("repo_name", ASCENDING), ("insight_type", ASCENDING)])
        await self.users_collection.create_index([("user_id", ASCENDING)], unique=True)
        await self.users_collection.create_index([("email", ASCENDING)], unique=True)
        await self.users_collection.create_index([("username", ASCENDING)], unique=True)
        await self.sessions_collection.create_index([("session_id", ASCENDING)], unique=True)
        await self.sessions_collection.create_index([("user_id", ASCENDING), ("status", ASCENDING)])
        await self.yme_collection.create_index([("user_id", ASCENDING), ("timestamp", ASCENDING)])
        await self.yme_collection.create_index([("event_type", ASCENDING), ("timestamp", ASCENDING)])
        await self.yme_collection.create_index([("user_id", ASCENDING), ("event_type", ASCENDING), ("timestamp", ASCENDING)])
        await self.yme_memories_collection.create_index([("memory_id", ASCENDING)], unique=True)
        await self.yme_memories_collection.create_index([("user_id", ASCENDING), ("memory_type", ASCENDING), ("updated_at", ASCENDING)])
        await self.yme_memories_collection.create_index([("user_id", ASCENDING), ("importance_score", ASCENDING)])
        await self.yme_memories_collection.create_index([("user_id", ASCENDING), ("tags", ASCENDING)])
        await self.yme_memories_collection.create_index([("user_id", ASCENDING), ("dedupe_key", ASCENDING)])
        await self.yme_memories_collection.create_index([("user_id", ASCENDING), ("status", ASCENDING), ("updated_at", ASCENDING)])
        await self.yme_graph_collection.create_index([("edge_id", ASCENDING)], unique=True)
        await self.yme_graph_collection.create_index([("user_id", ASCENDING), ("left_node", ASCENDING)])
        await self.yme_graph_collection.create_index([("user_id", ASCENDING), ("right_node", ASCENDING)])
        await self.conversations_collection.create_index([("conversation_id", ASCENDING)], unique=True)
        await self.conversations_collection.create_index([("user_id", ASCENDING), ("created_at", ASCENDING)])
        await self.security_alerts_collection.create_index([("created_at", ASCENDING)])
        await self.events_collection.create_index([("event_type", ASCENDING), ("timestamp", ASCENDING)])
        await self.events_collection.create_index([("category", ASCENDING), ("timestamp", ASCENDING)])
        await self.events_collection.create_index([("trace_id", ASCENDING), ("timestamp", ASCENDING)])
        await self.events_collection.create_index([("source_module", ASCENDING), ("timestamp", ASCENDING)])
        await self.events_collection.create_index([("event_id", ASCENDING)], unique=True)
        await self.events_collection.create_index([("source", ASCENDING), ("timestamp", ASCENDING)])
        await self.events_collection.create_index([("processing_status", ASCENDING), ("ingested_at", ASCENDING)])
        await self.logs_collection.create_index([("service", ASCENDING), ("timestamp", ASCENDING)])
        await self.logs_collection.create_index([("level", ASCENDING), ("timestamp", ASCENDING)])
        await self.logs_collection.create_index([("stack_signature", ASCENDING), ("timestamp", ASCENDING)])
        await self.logs_collection.create_index([("message_signature", ASCENDING), ("timestamp", ASCENDING)])
        await self.log_alerts_collection.create_index([("service", ASCENDING), ("severity", ASCENDING), ("created_at", ASCENDING)])
        await self.log_alerts_collection.create_index([("alert_type", ASCENDING), ("created_at", ASCENDING)])
        await self.moderation_alerts_collection.create_index([("event_id", ASCENDING)], unique=True)
        await self.moderation_alerts_collection.create_index([("status", ASCENDING), ("created_at", ASCENDING)])
        await self.engagement_metrics_collection.create_index(
            [("source", ASCENDING), ("event_type", ASCENDING), ("bucket_start", ASCENDING)],
            unique=True,
        )
        await self.ai_insights_collection.create_index([("insight_type", ASCENDING), ("created_at", ASCENDING)])
        await self.ai_insights_collection.create_index([("status", ASCENDING), ("created_at", ASCENDING)])
        await self.github_repositories_collection.create_index([("full_name", ASCENDING)], unique=True)
        await self.github_repositories_collection.create_index([("repo_name", ASCENDING)], unique=True)
        await self.github_repositories_collection.create_index([("sync_status", ASCENDING), ("updated_at", ASCENDING)])
        await self.repo_architecture_collection.create_index([("architecture_id", ASCENDING)], unique=True)
        await self.repo_architecture_collection.create_index([("full_name", ASCENDING), ("generated_at", ASCENDING)])
        await self.repo_architecture_collection.create_index([("repo_name", ASCENDING), ("generated_at", ASCENDING)])

    async def ping(self) -> None:
        if self.async_client is None:
            raise RuntimeError("MongoDB is not configured.")
        await self.async_client.admin.command("ping")

    async def close(self) -> None:
        if self.async_client is not None:
            self.async_client.close()
        if self.sync_client is not None:
            await asyncio.to_thread(self.sync_client.close)
