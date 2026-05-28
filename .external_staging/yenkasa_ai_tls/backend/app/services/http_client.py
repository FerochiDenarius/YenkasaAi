from __future__ import annotations

import logging
import ssl
import threading
import time
from typing import Any

import certifi
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


LOGGER = logging.getLogger("yenkasa_ai_cloud.http_client")

DEFAULT_TIMEOUT = (5, 30)
GITHUB_TIMEOUT = (10, 60)

TRANSIENT_EXCEPTIONS = (
    requests.exceptions.ConnectionError,
    requests.exceptions.Timeout,
    requests.exceptions.SSLError,
    requests.exceptions.ChunkedEncodingError,
)

_SESSION_LOCK = threading.Lock()
_SESSIONS: dict[str, requests.Session] = {}


class SSLAdapter(HTTPAdapter):
    def _build_ssl_context(self) -> ssl.SSLContext:
        context = ssl.create_default_context(cafile=certifi.where())
        if hasattr(ssl, "TLSVersion"):
            context.minimum_version = ssl.TLSVersion.TLSv1_2
        return context

    def init_poolmanager(self, *args, **kwargs):
        kwargs["ssl_context"] = self._build_ssl_context()
        return super().init_poolmanager(*args, **kwargs)

    def proxy_manager_for(self, *args, **kwargs):
        kwargs["ssl_context"] = self._build_ssl_context()
        return super().proxy_manager_for(*args, **kwargs)


def _build_retry(allowed_methods: frozenset[str] | None = None) -> Retry:
    return Retry(
        total=10,
        connect=10,
        read=10,
        backoff_factor=2,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=allowed_methods or frozenset({"HEAD", "GET", "OPTIONS", "POST"}),
        raise_on_status=False,
        respect_retry_after_header=True,
    )


def _create_session(
    *,
    user_agent: str,
    accept: str,
    connection_close: bool,
    pool_connections: int = 20,
    pool_maxsize: int = 20,
) -> requests.Session:
    adapter = SSLAdapter(
        max_retries=_build_retry(),
        pool_connections=pool_connections,
        pool_maxsize=pool_maxsize,
    )
    session = requests.Session()
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    session.headers.update(
        {
            "Accept": accept,
            "User-Agent": user_agent,
        }
    )
    if connection_close:
        session.headers["Connection"] = "close"
    return session


def create_default_session() -> requests.Session:
    return _create_session(
        user_agent="YenkasaAI-Backend/1.0",
        accept="application/json",
        connection_close=False,
        pool_connections=20,
        pool_maxsize=50,
    )


def create_github_session() -> requests.Session:
    return _create_session(
        user_agent="YenkasaAI/1.0",
        accept="application/vnd.github+json",
        connection_close=True,
        pool_connections=20,
        pool_maxsize=20,
    )


def _build_session(session_name: str) -> requests.Session:
    if session_name == "github":
        return create_github_session()
    return create_default_session()


def _normalize_log_context(context: dict[str, Any] | None) -> dict[str, Any]:
    return dict(context or {})


def _is_transient_response(response: requests.Response) -> bool:
    return response.status_code in {429, 500, 502, 503, 504}


def _resolve_timeout(session_name: str, timeout: tuple[int, int] | None) -> tuple[int, int]:
    if timeout is not None:
        return timeout
    if session_name == "github":
        return GITHUB_TIMEOUT
    return DEFAULT_TIMEOUT


def _retry_delay(attempt: int) -> int:
    return min(2 ** attempt, 15)


def _should_recycle_session(exc: Exception) -> bool:
    if isinstance(
        exc,
        (
            requests.exceptions.ConnectionError,
            requests.exceptions.SSLError,
            requests.exceptions.ChunkedEncodingError,
        ),
    ):
        return True
    error_text = str(exc).lower()
    return any(
        marker in error_text
        for marker in (
            "unexpected eof while reading",
            "eof occurred in violation of protocol",
            "connection reset by peer",
            "remote end closed connection",
            "remote disconnected",
            "tlsv1 alert internal error",
        )
    )


def get_session(session_name: str = "default") -> requests.Session:
    with _SESSION_LOCK:
        session = _SESSIONS.get(session_name)
        if session is None:
            session = _build_session(session_name)
            _SESSIONS[session_name] = session
        return session


def reset_session(session_name: str = "default") -> requests.Session:
    with _SESSION_LOCK:
        previous = _SESSIONS.pop(session_name, None)
        if previous is not None:
            previous.close()
        session = _build_session(session_name)
        _SESSIONS[session_name] = session
        return session


def close_all_sessions() -> None:
    with _SESSION_LOCK:
        for session in _SESSIONS.values():
            session.close()
        _SESSIONS.clear()


def request(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    params: dict[str, Any] | None = None,
    json: Any | None = None,
    data: Any | None = None,
    timeout: tuple[int, int] | None = None,
    attempts: int = 3,
    session_name: str = "default",
    log_context: dict[str, Any] | None = None,
) -> requests.Response:
    context = _normalize_log_context(log_context)
    last_error: Exception | None = None
    resolved_timeout = _resolve_timeout(session_name, timeout)

    for attempt in range(1, max(1, attempts) + 1):
        try:
            response = get_session(session_name).request(
                method=method.upper(),
                url=url,
                headers=headers,
                params=params,
                json=json,
                data=data,
                timeout=resolved_timeout,
            )

            if _is_transient_response(response) and attempt < attempts:
                delay = _retry_delay(attempt)
                LOGGER.warning(
                    "External HTTP request returned transient status; retrying.",
                    extra={
                        "extra": {
                            "method": method.upper(),
                            "url": url,
                            "status_code": response.status_code,
                            "attempt": attempt,
                            "attempts": attempts,
                            "delay_s": delay,
                            "session_name": session_name,
                            **context,
                        }
                    },
                )
                response.close()
                time.sleep(delay)
                continue

            response.raise_for_status()
            return response
        except TRANSIENT_EXCEPTIONS as exc:
            last_error = exc
            if _should_recycle_session(exc):
                reset_session(session_name)
            if attempt >= attempts:
                break
            delay = _retry_delay(attempt)
            LOGGER.warning(
                "External HTTP request failed; retrying.",
                extra={
                    "extra": {
                        "method": method.upper(),
                        "url": url,
                        "attempt": attempt,
                        "attempts": attempts,
                        "delay_s": delay,
                        "error": str(exc),
                        "session_name": session_name,
                        **context,
                    }
                },
            )
            time.sleep(delay)

    if last_error is None:
        raise RuntimeError(f"External HTTP request exhausted without a captured error for {method.upper()} {url}")
    LOGGER.error(
        "External HTTP request failed after retries.",
        extra={
            "extra": {
                "method": method.upper(),
                "url": url,
                "attempts": attempts,
                "error": str(last_error),
                "session_name": session_name,
                **context,
            }
        },
    )
    raise last_error


def request_json(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    params: dict[str, Any] | None = None,
    json: Any | None = None,
    data: Any | None = None,
    timeout: tuple[int, int] | None = None,
    attempts: int = 3,
    session_name: str = "default",
    log_context: dict[str, Any] | None = None,
) -> Any:
    response = request(
        method,
        url,
        headers=headers,
        params=params,
        json=json,
        data=data,
        timeout=timeout,
        attempts=attempts,
        session_name=session_name,
        log_context=log_context,
    )
    try:
        if not response.content:
            return None
        return response.json()
    finally:
        response.close()
