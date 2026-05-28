from __future__ import annotations

import unittest

from app.main import app


class AppRouteTests(unittest.TestCase):
    def test_app_mounts_legacy_and_yme_routes(self) -> None:
        paths = {route.path for route in app.routes}
        required = {
            "/health",
            "/chat",
            "/search",
            "/api/auth/register",
            "/api/events",
            "/api/events/ingest",
            "/api/yme/health",
            "/api/yme/search",
            "/api/yme/memories",
            "/api/admin/yme/analytics",
        }
        self.assertTrue(required.issubset(paths))


if __name__ == "__main__":
    unittest.main()
