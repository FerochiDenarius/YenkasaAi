from __future__ import annotations

import unittest
from types import SimpleNamespace

from jose import jwt

from app.modules.security.tokens import TokenService


class TokenServiceTests(unittest.TestCase):
    def test_access_token_supports_24_hour_session_window(self) -> None:
        settings = SimpleNamespace(
            access_token_ttl_minutes=1440,
            refresh_token_ttl_days=30,
            jwt_secret_key="test-secret",
            jwt_algorithm="HS256",
        )
        service = TokenService(settings)

        token, expires_in = service.create_access_token("user-1", "session-1", "admin")
        payload = jwt.decode(token, "test-secret", algorithms=["HS256"])

        self.assertEqual(expires_in, 86400)
        self.assertEqual(payload["type"], "access")
        self.assertGreaterEqual(payload["exp"] - payload["iat"], 86399)


if __name__ == "__main__":
    unittest.main()
