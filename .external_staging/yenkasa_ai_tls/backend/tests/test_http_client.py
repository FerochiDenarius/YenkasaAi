from __future__ import annotations

import unittest
from unittest.mock import Mock
from unittest.mock import patch

import requests

from app.services.http_client import GITHUB_TIMEOUT
from app.services.http_client import SSLAdapter
from app.services.http_client import create_github_session
from app.services.http_client import request_json


class _FakeResponse:
    def __init__(self, payload: object, status_code: int = 200, headers: dict[str, str] | None = None) -> None:
        self._payload = payload
        self.status_code = status_code
        self.headers = headers or {}
        self.content = b"" if payload is None else b'{"ok": true}'
        self.closed = False

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise requests.exceptions.HTTPError(response=self)

    def json(self) -> object:
        return self._payload

    def close(self) -> None:
        self.closed = True


class HttpClientTests(unittest.TestCase):
    def test_create_github_session_applies_tls_adapter_and_headers(self) -> None:
        session = create_github_session()
        try:
            self.assertEqual(session.headers["Accept"], "application/vnd.github+json")
            self.assertEqual(session.headers["User-Agent"], "YenkasaAI/1.0")
            self.assertEqual(session.headers["Connection"], "close")
            self.assertIsInstance(session.get_adapter("https://api.github.com"), SSLAdapter)
        finally:
            session.close()

    def test_request_json_recovers_from_transient_ssl_error(self) -> None:
        first_session = Mock()
        second_session = Mock()
        first_session.request.side_effect = requests.exceptions.SSLError("EOF occurred in violation of protocol")
        response = _FakeResponse({"ok": True})
        second_session.request.return_value = response

        with (
            patch("app.services.http_client.get_session", side_effect=[first_session, second_session]) as get_session,
            patch("app.services.http_client.reset_session") as reset_session,
            patch("app.services.http_client.time.sleep", return_value=None),
        ):
            payload = request_json(
                "GET",
                "https://api.github.com/repos/example/repo",
                session_name="github",
                attempts=2,
            )

        self.assertEqual(payload, {"ok": True})
        self.assertEqual(get_session.call_count, 2)
        reset_session.assert_called_once_with("github")
        self.assertTrue(response.closed)
        self.assertEqual(second_session.request.call_args.kwargs["timeout"], GITHUB_TIMEOUT)


if __name__ == "__main__":
    unittest.main()
