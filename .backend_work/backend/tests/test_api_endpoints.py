from __future__ import annotations

import pytest


def test_health_endpoint(client):
    response = client.get("/health", headers={"X-Request-ID": "health-1"})

    assert response.status_code == 200
    assert response.json()["status"] == "operational"
    assert response.headers["x-request-id"] == "health-1"


@pytest.mark.parametrize(
    ("path", "payload", "expected_prefix"),
    [
        ("/api/auth/register", {"username": "new-user", "email": "new@example.com", "password": "password123"}, "registered"),
        ("/api/auth/login", {"email": "developer@example.com", "password": "password123"}, "logged-in"),
        ("/api/auth/refresh", {"refresh_token": "refresh-token-value-1234567890"}, "refreshed"),
    ],
)
def test_auth_token_endpoints(client, path, payload, expected_prefix):
    response = client.post(path, json=payload)

    assert response.status_code == 200
    assert response.json()["access_token"].startswith(expected_prefix)
    assert response.json()["user"]["role"] == "developer"


def test_me_and_logout_require_and_use_an_active_session(client, auth_headers, intelligence_runtime):
    me_response = client.get("/api/auth/me", headers=auth_headers)
    logout_response = client.post("/api/auth/logout", headers=auth_headers)

    assert me_response.status_code == 200
    assert me_response.json()["email"] == "developer@example.com"
    assert logout_response.json() == {"status": "logged_out"}
    assert intelligence_runtime.auth.logout_calls == ["session-1"]


def test_legacy_chat_search_and_ingest_endpoints(client, auth_headers):
    chat = client.post("/chat", headers=auth_headers, json={"question": "What is Yenkasa?"})
    search = client.post("/search", headers=auth_headers, json={"question": "Find architecture"})
    ingest = client.post(
        "/ingest?audience=engineering",
        headers=auth_headers,
        files={"files": ("notes.txt", b"test content", "text/plain")},
    )

    assert chat.status_code == 200
    assert chat.json()["answer"] == "A test answer."
    assert search.status_code == 200
    assert search.json()["count"] == 0
    assert ingest.status_code == 200
    assert ingest.json()["accepted_files"] == 1
    assert ingest.json()["target_collection"] == "engineering"


def test_repository_ingestion_create_and_get(client, auth_headers):
    create = client.post(
        "/api/repo/ingestions",
        headers=auth_headers,
        json={"repo_path": "/tmp/sample-repo", "repo_name": "sample-repo"},
    )
    get_job = client.get("/api/repo/ingestions/job-1", headers=auth_headers)

    assert create.status_code == 200
    assert create.json()["job_id"] == "job-1"
    assert get_job.status_code == 200
    assert get_job.json()["status"] == "queued"


def test_repository_search_and_chat_track_interactions(client, auth_headers, intelligence_runtime):
    search = client.get(
        "/api/repo/search?q=health&repo_name=sample-repo&top_k=1",
        headers=auth_headers,
    )
    chat = client.post(
        "/api/repo/chat",
        headers=auth_headers,
        json={"question": "How does health work?", "repo_name": "sample-repo"},
    )

    assert search.status_code == 200
    assert search.json()["results"][0]["file_path"] == "app.py"
    assert chat.status_code == 200
    assert chat.json()["answer"].startswith("The health")
    assert [call["feature"] for call in intelligence_runtime.tracking.calls] == ["repo_search", "repo_chat"]


def test_event_ingestion(client, auth_headers):
    response = client.post(
        "/api/events",
        headers=auth_headers,
        json={"event_type": "comment_created", "user_id": "user-1", "app_source": "web"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "accepted"
    assert response.json()["event_type"] == "comment_created"


@pytest.mark.parametrize(
    "path",
    [
        "/api/admin/analytics/overview",
        "/api/admin/analytics/usage",
        "/api/admin/analytics/users",
        "/api/admin/users?limit=10",
        "/api/admin/active-sessions?limit=10",
        "/api/admin/ai-usage?limit=10",
        "/api/admin/security-alerts?limit=10",
        "/api/admin/repo-insights?repo_name=sample-repo&limit=10",
        "/api/admin/system-health",
        "/api/admin/recommendations?repo_name=sample-repo",
    ],
)
def test_admin_endpoints(client, admin_headers, path):
    response = client.get(path, headers=admin_headers)

    assert response.status_code == 200
    assert response.json()


def test_validation_errors_are_normalized(client):
    response = client.post(
        "/api/auth/login",
        headers={"X-Request-ID": "validation-1"},
        json={"email": "bad"},
    )

    assert response.status_code == 422
    assert response.json() == {
        "success": False,
        "error": "Invalid request payload",
        "request_id": "validation-1",
    }
    assert response.headers["x-request-id"] == "validation-1"


def test_authentication_and_authorization_errors(client, auth_headers):
    unauthenticated = client.get("/api/auth/me")
    forbidden = client.get("/api/admin/users", headers=auth_headers)

    assert unauthenticated.status_code == 401
    assert unauthenticated.json()["error"] == "Authentication required."
    assert forbidden.status_code == 403
    assert forbidden.json()["error"] == "Insufficient permissions."


def test_rate_limit_maps_to_too_many_requests(client, auth_headers, intelligence_runtime):
    intelligence_runtime.security.rate_limited = True

    response = client.get("/api/repo/search?q=health", headers=auth_headers)

    assert response.status_code == 429
    assert response.json()["error"] == "AI usage rate limit exceeded."


def test_repository_service_errors_map_to_client_errors(client, auth_headers, intelligence_runtime):
    intelligence_runtime.repo_ingestion.raise_enqueue = "value"
    invalid_path = client.post(
        "/api/repo/ingestions",
        headers=auth_headers,
        json={"repo_path": "/outside"},
    )

    intelligence_runtime.repo_ingestion.raise_enqueue = "runtime"
    unavailable = client.post(
        "/api/repo/ingestions",
        headers=auth_headers,
        json={"repo_path": "/tmp/sample-repo"},
    )

    intelligence_runtime.repo_ingestion.raise_get = True
    missing = client.get("/api/repo/ingestions/missing", headers=auth_headers)

    assert invalid_path.status_code == 400
    assert unavailable.status_code == 503
    assert missing.status_code == 404


def test_unhandled_ai_failure_is_sanitized(client, auth_headers, intelligence_runtime):
    intelligence_runtime.repo_chat.raise_error = True

    response = client.post(
        "/api/repo/chat",
        headers={**auth_headers, "X-Request-ID": "ai-failure-1"},
        json={"question": "trigger failure"},
    )

    assert response.status_code == 500
    assert response.json() == {
        "success": False,
        "error": "AI processing failed",
        "request_id": "ai-failure-1",
    }


def test_runtime_dependency_returns_service_unavailable(client):
    client.app.state.intelligence_runtime = None
    client.app.dependency_overrides.clear()

    response = client.post(
        "/api/auth/register",
        json={"username": "new-user", "email": "new@example.com", "password": "password123"},
    )

    assert response.status_code == 503
    assert response.json()["error"] == "Dev intelligence runtime is not ready."
