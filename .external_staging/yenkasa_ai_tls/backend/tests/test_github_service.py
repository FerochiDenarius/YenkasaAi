from __future__ import annotations

import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock
from unittest.mock import patch

from app.modules.github.service import GitHubSyncService


class _FakeResponse:
    def __init__(self, payload: object, headers: dict[str, str] | None = None) -> None:
        self._payload = payload
        self.headers = headers or {}
        self.status_code = 200
        self.content = b'{"ok": true}'
        self.closed = False

    def json(self) -> object:
        return self._payload

    def close(self) -> None:
        self.closed = True


class GitHubSyncServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        settings = SimpleNamespace(
            github_token="token",
            github_repo_cache_root=Path("/tmp/yenkasa-github-cache"),
            github_clone_depth=1,
            github_owner="",
            github_metadata_cache_ttl_s=300,
            github_low_rate_limit_threshold=250,
        )
        self.service = GitHubSyncService(settings, mongo_service=SimpleNamespace(), repo_ingestion_service=SimpleNamespace())

    async def test_github_get_json_caches_metadata_and_records_rate_limit(self) -> None:
        response = _FakeResponse(
            {"name": "repo"},
            headers={
                "X-RateLimit-Limit": "5000",
                "X-RateLimit-Remaining": "4999",
                "X-RateLimit-Reset": "2000000000",
                "X-RateLimit-Resource": "core",
            },
        )

        with patch("app.modules.github.service.request", return_value=response) as request_mock:
            first = await self.service._github_get_json("/repos/example/repo", label="get_repo:example/repo")
            second = await self.service._github_get_json("/repos/example/repo", label="get_repo:example/repo")

        self.assertEqual(first, {"name": "repo"})
        self.assertEqual(second, {"name": "repo"})
        request_mock.assert_called_once()
        self.assertEqual(self.service.rate_limit_status()["remaining"], 4999)
        self.assertTrue(response.closed)

    async def test_sync_all_accessible_repositories_passes_repo_metadata_from_listing(self) -> None:
        repo = {
            "full_name": "acme/platform",
            "name": "platform",
            "owner": {"login": "acme"},
            "default_branch": "main",
            "clone_url": "https://github.com/acme/platform.git",
            "html_url": "https://github.com/acme/platform",
            "private": True,
            "archived": False,
            "disabled": False,
            "language": "Python",
            "topics": ["fastapi"],
            "size": 42,
            "open_issues_count": 7,
            "pushed_at": "2026-05-27T10:00:00Z",
        }

        with (
            patch.object(self.service, "_resolve_repository_list", new=AsyncMock(return_value=[repo])),
            patch.object(
                self.service,
                "sync_repository_from_payload",
                new=AsyncMock(return_value={"status": "completed", "full_name": repo["full_name"]}),
            ) as sync_mock,
        ):
            result = await self.service.sync_all_accessible_repositories(owner="acme", force_reingest=True)

        payload = sync_mock.await_args.args[0]
        self.assertEqual(payload["clone_url"], repo["clone_url"])
        self.assertEqual(payload["default_branch"], "main")
        self.assertEqual(payload["primary_language"], "Python")
        self.assertTrue(payload["force_reingest"])
        self.assertEqual(result["synced_count"], 1)
        self.assertEqual(result["failed_count"], 0)


if __name__ == "__main__":
    unittest.main()
