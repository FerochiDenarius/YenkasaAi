from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from urllib.parse import quote
from uuid import uuid4

import requests

from app.models import GitHubRepositoryDocument
from app.services.http_client import GITHUB_TIMEOUT
from app.services.http_client import request


LOGGER = logging.getLogger("yenkasa_ai_cloud.github")


@dataclass(slots=True)
class _GitHubCacheEntry:
    value: object
    expires_at: float


class GitHubSyncService:
    def __init__(self, settings, mongo_service, repo_ingestion_service) -> None:
        self.settings = settings
        self.mongo = mongo_service
        self.repo_ingestion = repo_ingestion_service
        self._github_api_base = "https://api.github.com"
        self._metadata_cache: dict[tuple[str, tuple[tuple[str, str], ...]], _GitHubCacheEntry] = {}
        self._last_rate_limit: dict[str, object] = {
            "limit": None,
            "remaining": None,
            "reset_at": None,
            "resource": None,
            "status_code": None,
        }

    def _github_headers(self) -> dict[str, str]:
        token = self.settings.github_token.strip()
        if not token:
            raise RuntimeError("GITHUB_TOKEN is not configured.")
        return {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }

    def _cache_key(self, path: str, params: dict[str, object] | None) -> tuple[str, tuple[tuple[str, str], ...]]:
        normalized = tuple(sorted((key, str(value)) for key, value in (params or {}).items()))
        return path, normalized

    def _cache_get(self, path: str, params: dict[str, object] | None) -> object | None:
        cache_key = self._cache_key(path, params)
        entry = self._metadata_cache.get(cache_key)
        if entry is None:
            return None
        if entry.expires_at <= time.monotonic():
            self._metadata_cache.pop(cache_key, None)
            return None
        return entry.value

    def _cache_set(self, path: str, params: dict[str, object] | None, value: object) -> None:
        ttl_s = max(int(self.settings.github_metadata_cache_ttl_s), 0)
        if ttl_s <= 0:
            return
        self._metadata_cache[self._cache_key(path, params)] = _GitHubCacheEntry(
            value=value,
            expires_at=time.monotonic() + ttl_s,
        )

    def _owner_login(self, payload: dict, full_name: str = "") -> str:
        owner = payload.get("owner")
        if isinstance(owner, dict):
            login = str(owner.get("login") or "").strip()
            if login:
                return login
        if isinstance(owner, str) and owner.strip():
            return owner.strip()
        if "/" in full_name:
            return full_name.split("/", 1)[0]
        return ""

    def _parse_header_int(self, value: str | None) -> int | None:
        if value is None or value == "":
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    def _record_rate_limit(self, headers: requests.structures.CaseInsensitiveDict | dict[str, str], *, label: str, path: str, status_code: int | None) -> None:
        limit = self._parse_header_int(headers.get("X-RateLimit-Limit"))
        remaining = self._parse_header_int(headers.get("X-RateLimit-Remaining"))
        reset_epoch = self._parse_header_int(headers.get("X-RateLimit-Reset"))
        reset_at = datetime.utcfromtimestamp(reset_epoch).isoformat() + "Z" if reset_epoch else None
        resource = headers.get("X-RateLimit-Resource")

        self._last_rate_limit = {
            "limit": limit,
            "remaining": remaining,
            "reset_at": reset_at,
            "resource": resource,
            "status_code": status_code,
        }

        if remaining is None:
            return

        if remaining <= self.settings.github_low_rate_limit_threshold:
            log_level = logging.ERROR if remaining == 0 else logging.WARNING
            LOGGER.log(
                log_level,
                "GitHub rate limit is low label=%s path=%s remaining=%s limit=%s reset_at=%s resource=%s status=%s",
                label,
                path,
                remaining,
                limit,
                reset_at,
                resource,
                status_code,
            )

    def _payload_has_remote_repo_metadata(self, payload: dict) -> bool:
        return bool(payload.get("clone_url") and (payload.get("default_branch") or payload.get("branch")))

    def rate_limit_status(self) -> dict[str, object]:
        return dict(self._last_rate_limit)

    async def _github_get_json(
        self,
        path: str,
        *,
        params: dict[str, object] | None = None,
        label: str,
        attempts: int = 4,
    ):
        cached = self._cache_get(path, params)
        if cached is not None:
            return cached

        url = f"{self._github_api_base}{path}"
        try:
            response = await asyncio.to_thread(
                request,
                "GET",
                url,
                headers=self._github_headers(),
                params=params,
                timeout=GITHUB_TIMEOUT,
                attempts=attempts,
                session_name="github",
                log_context={
                    "component": "github_sync",
                    "label": label,
                    "github_path": path,
                },
            )
        except requests.exceptions.HTTPError as exc:
            if exc.response is not None:
                try:
                    self._record_rate_limit(exc.response.headers, label=label, path=path, status_code=exc.response.status_code)
                finally:
                    exc.response.close()
            raise

        try:
            self._record_rate_limit(response.headers, label=label, path=path, status_code=response.status_code)
            payload = None if not response.content else response.json()
        finally:
            response.close()

        self._cache_set(path, params, payload)
        return payload

    def _repo_cache_path(self, full_name: str) -> Path:
        safe_name = full_name.strip().replace("/", "__")
        return self.settings.github_repo_cache_root / safe_name

    def _credentialized_clone_url(self, clone_url: str) -> str:
        token = self.settings.github_token.strip()
        if not token or not clone_url.startswith("https://"):
            return clone_url
        return clone_url.replace("https://", f"https://x-access-token:{quote(token, safe='')}@", 1)

    async def _clone_or_update_repository(self, *, full_name: str, clone_url: str, default_branch: str) -> Path:
        local_path = self._repo_cache_path(full_name)
        local_path.parent.mkdir(parents=True, exist_ok=True)
        auth_clone_url = self._credentialized_clone_url(clone_url)

        def _clone() -> Path:
            try:
                from git import GitCommandError
                from git import Repo as GitRepo
            except ModuleNotFoundError as exc:  # pragma: no cover - dependency guard
                raise RuntimeError("GitPython is not installed.") from exc

            if not local_path.exists():
                GitRepo.clone_from(
                    auth_clone_url,
                    local_path,
                    depth=max(int(self.settings.github_clone_depth), 1),
                    branch=default_branch,
                )
                return local_path

            repo = GitRepo(local_path)
            try:
                repo.remote().set_url(auth_clone_url)
            except Exception:
                pass
            try:
                repo.remote().fetch(prune=True, tags=True)
            except GitCommandError:
                repo.git.fetch("--all", "--prune")

            try:
                repo.git.checkout(default_branch)
            except GitCommandError:
                repo.git.checkout("-B", default_branch, f"origin/{default_branch}")

            try:
                repo.git.reset("--hard", f"origin/{default_branch}")
            except GitCommandError:
                pass
            return local_path

        return await asyncio.to_thread(_clone)

    async def _resolve_remote_repository(self, full_name: str) -> dict:
        path = f"/repos/{quote(full_name, safe='')}"
        return await self._github_get_json(path, label=f"get_repo:{full_name}")

    async def _resolve_repository_list(self, owner: str | None = None) -> list[dict]:
        repositories = await self._github_get_json(
            "/user/repos",
            params={
                "per_page": 100,
                "visibility": "all",
                "affiliation": "owner,collaborator,organization_member",
                "sort": "updated",
                "direction": "desc",
            },
            label=f"get_repos:{owner or 'authenticated_user'}",
        )
        if not isinstance(repositories, list):
            return []
        if owner:
            normalized_owner = owner.strip().lower()
            repositories = [
                repo
                for repo in repositories
                if str(repo.get("owner", {}).get("login", "")).strip().lower() == normalized_owner
            ]
        return repositories

    async def _extract_commit_metadata(self, full_name: str) -> dict[str, object]:
        try:
            commits = await self._github_get_json(
                f"/repos/{quote(full_name, safe='')}/commits",
                params={"per_page": 1},
                label=f"get_commit:{full_name}",
            )
            if not commits:
                return {}
            first_commit = commits[0]
        except Exception:
            return {}

        return {
            "last_commit_sha": first_commit.get("sha"),
            "last_commit_message": first_commit.get("commit", {}).get("message"),
            "last_commit_author": first_commit.get("commit", {}).get("author", {}).get("name"),
            "last_commit_at": first_commit.get("commit", {}).get("author", {}).get("date"),
        }

    async def sync_repository_from_payload(self, payload: dict) -> dict:
        if payload.get("sync_all_repos"):
            return await self.sync_all_accessible_repositories(
                owner=payload.get("owner") or self.settings.github_owner or None,
                force_reingest=bool(payload.get("force_reingest", False)),
            )

        repo_path_value = payload.get("repo_path") or payload.get("local_path")
        full_name = str(payload.get("full_name") or "").strip()

        if full_name and not repo_path_value:
            remote_repo = payload if self._payload_has_remote_repo_metadata(payload) else await self._resolve_remote_repository(full_name)
            repo_full_name = str(remote_repo.get("full_name") or full_name)
            clone_url = str(remote_repo.get("clone_url") or payload.get("clone_url") or "")
            default_branch = str(remote_repo.get("default_branch") or payload.get("default_branch") or payload.get("branch") or "main")
            repo_path = await self._clone_or_update_repository(
                full_name=repo_full_name,
                clone_url=clone_url,
                default_branch=default_branch,
            )
            repo_path_value = str(repo_path)
            commit_metadata = (
                {
                    "last_commit_sha": payload.get("last_commit_sha"),
                    "last_commit_message": payload.get("last_commit_message"),
                    "last_commit_author": payload.get("last_commit_author"),
                    "last_commit_at": payload.get("last_commit_at"),
                }
                if payload.get("last_commit_sha")
                else await self._extract_commit_metadata(repo_full_name)
            )
            payload = {
                **payload,
                "repo_path": repo_path_value,
                "repo_name": payload.get("repo_name") or remote_repo.get("name") or repo_full_name.split("/")[-1],
                "full_name": repo_full_name,
                "owner": self._owner_login(remote_repo, repo_full_name),
                "name": remote_repo.get("name") or payload.get("name") or repo_full_name.split("/")[-1],
                "default_branch": default_branch,
                "clone_url": clone_url,
                "html_url": remote_repo.get("html_url") or payload.get("html_url"),
                "private": bool(remote_repo.get("private", payload.get("private", False))),
                "archived": bool(remote_repo.get("archived", payload.get("archived", False))),
                "disabled": bool(remote_repo.get("disabled", payload.get("disabled", False))),
                "primary_language": remote_repo.get("language") or payload.get("primary_language"),
                "topics": list(remote_repo.get("topics") or payload.get("topics") or []),
                "branch_names": [default_branch] if default_branch else list(payload.get("branch_names") or []),
                "size_kb": int(remote_repo.get("size_kb") or remote_repo.get("size") or payload.get("size_kb") or 0),
                "open_issues_count": int(remote_repo.get("open_issues_count") or payload.get("open_issues_count") or 0),
                "last_pushed_at": remote_repo.get("pushed_at") or payload.get("last_pushed_at"),
                **commit_metadata,
            }

        if not repo_path_value:
            raise ValueError("GitHub sync payload requires repo_path, local_path, or full_name.")

        repo_path = Path(repo_path_value)
        repo_name = str(payload.get("repo_name") or payload.get("full_name") or repo_path.name).strip()
        if not repo_name:
            raise ValueError("GitHub sync payload requires a repository name.")

        now = datetime.utcnow()
        repository = GitHubRepositoryDocument(
            repository_id=str(payload.get("repository_id") or payload.get("repo_id") or uuid4()),
            full_name=str(payload.get("full_name") or repo_name),
            owner=str(payload.get("owner") or payload.get("github_owner") or "").strip(),
            name=str(payload.get("name") or repo_name.split("/")[-1]),
            repo_name=repo_name,
            default_branch=str(payload.get("default_branch") or payload.get("branch") or "main"),
            clone_url=str(payload.get("clone_url") or ""),
            html_url=str(payload.get("html_url") or ""),
            local_path=str(repo_path.resolve()),
            private=bool(payload.get("private", False)),
            archived=bool(payload.get("archived", False)),
            disabled=bool(payload.get("disabled", False)),
            primary_language=payload.get("primary_language"),
            topics=list(payload.get("topics") or []),
            branch_names=list(payload.get("branch_names") or []),
            size_kb=int(payload.get("size_kb") or 0),
            open_issues_count=int(payload.get("open_issues_count") or 0),
            sync_status="running",
            scan_status="running",
            stale=bool(payload.get("stale", False)),
            architecture_changed=False,
            dependency_fingerprint=payload.get("dependency_fingerprint"),
            architecture_fingerprint=payload.get("architecture_fingerprint"),
            last_pushed_at=payload.get("last_pushed_at"),
            last_synced_at=now,
            last_scanned_at=None,
            last_commit_sha=payload.get("last_commit_sha"),
            last_commit_message=payload.get("last_commit_message"),
            last_commit_author=payload.get("last_commit_author"),
            last_commit_at=payload.get("last_commit_at"),
            last_error=None,
            repo_metrics=dict(payload.get("repo_metrics") or {}),
            created_at=now,
            updated_at=now,
        )

        await self.mongo.github_repositories_collection.update_one(
            {"full_name": repository.full_name},
            {"$set": repository.model_dump(mode="json")},
            upsert=True,
        )

        try:
            job = await self.repo_ingestion.ingest_repository(
                repo_path=repo_path,
                repo_name=repo_name,
                force_reingest=bool(payload.get("force_reingest", False)),
            )
        except Exception as exc:
            await self.mongo.github_repositories_collection.update_one(
                {"full_name": repository.full_name},
                {
                    "$set": {
                        "sync_status": "failed",
                        "scan_status": "failed",
                        "last_error": str(exc),
                        "updated_at": datetime.utcnow(),
                    }
                },
            )
            LOGGER.exception("GitHub repository sync failed full_name=%s repo_path=%s", repository.full_name, repo_path)
            raise

        await self.mongo.github_repositories_collection.update_one(
            {"full_name": repository.full_name},
            {
                "$set": {
                    "sync_status": "completed",
                    "scan_status": "completed",
                    "last_synced_at": datetime.utcnow(),
                    "last_scanned_at": datetime.utcnow(),
                    "last_error": None,
                    "repo_metrics": {
                        "files_total": job.files_total,
                        "files_processed": job.files_processed,
                        "chunks_indexed": job.chunks_indexed,
                        "failed_files": list(job.failed_files),
                    },
                    "updated_at": datetime.utcnow(),
                }
            },
        )

        LOGGER.info(
            "GitHub repository synced full_name=%s repo_path=%s files=%d chunks=%d",
            repository.full_name,
            repo_path,
            job.files_processed,
            job.chunks_indexed,
        )
        return {
            "status": "completed",
            "repository_id": repository.repository_id,
            "full_name": repository.full_name,
            "repo_name": repository.repo_name,
            "repo_path": str(repo_path.resolve()),
            "job": job.model_dump(mode="json"),
        }

    async def sync_all_accessible_repositories(
        self,
        owner: str | None = None,
        force_reingest: bool = False,
    ) -> dict:
        repositories = await self._resolve_repository_list(owner=owner)
        results: list[dict] = []
        failed: list[str] = []

        for repo in repositories:
            try:
                result = await self.sync_repository_from_payload(
                    {
                        "full_name": repo.get("full_name"),
                        "repo_name": repo.get("name"),
                        "owner": repo.get("owner", {}).get("login"),
                        "name": repo.get("name"),
                        "default_branch": repo.get("default_branch"),
                        "clone_url": repo.get("clone_url"),
                        "html_url": repo.get("html_url"),
                        "private": bool(repo.get("private", False)),
                        "archived": bool(repo.get("archived", False)),
                        "disabled": bool(repo.get("disabled", False)),
                        "primary_language": repo.get("language"),
                        "topics": list(repo.get("topics") or []),
                        "size_kb": int(repo.get("size", 0) or 0),
                        "open_issues_count": int(repo.get("open_issues_count", 0) or 0),
                        "last_pushed_at": repo.get("pushed_at"),
                        "force_reingest": force_reingest,
                    }
                )
                results.append(result)
            except Exception as exc:
                failed.append(f"{repo.get('full_name')}: {exc}")

        return {
            "status": "completed" if not failed else "completed_with_errors",
            "synced_count": len(results),
            "failed_count": len(failed),
            "repositories": results,
            "summary": [
                f"Synced {len(results)} repository(ies).",
                *failed[:5],
            ],
        }
