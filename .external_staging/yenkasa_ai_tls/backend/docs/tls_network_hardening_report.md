# TLS Compatibility And Network Resilience Report

Date: 2026-05-27

## 1. Insecure SSL code found

- No application-level `verify=False` usage was found in `app/`, `services/`, `tests/`, or `docs/`.
- No disabled hostname verification or `ssl.CERT_NONE` usage was found in application code.
- Existing risk before this change: GitHub traffic used a long-lived `requests.Session` without an explicit TLS context, without GitHub-specific timeout enforcement, and without stale-session recycling after EOF/SSL failures.

## 2. Pinned certificates found

- No leaf, intermediate, or root certificate pinning was found in the Python backend, Dockerfiles, or deployment docs.
- No hardcoded GitHub or Google certificate fingerprints were found.

## 3. Outdated dependency risks

- `requests`, `urllib3`, `certifi`, `cryptography`, and `pyOpenSSL` were not previously declared as first-class backend dependencies even though outbound HTTPS resilience depends on them.
- `PyGithub` was present but unused; it has been removed to reduce dependency surface area and avoid split GitHub transport behavior.

## 4. Custom trust stores

- No custom CA bundle loading was found in runtime code.
- Deployment guidance now explicitly warns against setting `REQUESTS_CA_BUNDLE` or `SSL_CERT_FILE` unless there is a deliberate trust-store replacement plan.

## 5. OpenSSL compatibility status

- The service and worker images already used `python:3.12-slim`, which is appropriate for Python 3.11+ and OpenSSL 3-era compatibility.
- Both Dockerfiles now explicitly install `ca-certificates` and `openssl`, refresh the trust store, and upgrade `pip/setuptools/wheel` during build.

## 6. Google ECDSA migration risks

- I did not find a public Google document in this audit that explicitly names a `Q2 2026` migration date.
- Current official Google guidance does recommend ECDSA key types and modern trust-root behavior, and Google Trust Services documents emphasize public roots and compatibility testing.
- Remaining risk prior to this change: clients with stale CA stores, RSA-only assumptions, or custom trust stores can fail when Google serves ECDSA-oriented chains.
- Mitigation applied: the backend now relies on the system trust store plus `certifi`, enforces a modern default TLS context, and avoids certificate pinning or RSA-only assumptions in application code.

## 7. GitHub connection instability causes

- The intermittent `UNEXPECTED_EOF_WHILE_READING` failure pattern is consistent with transient TLS/socket termination on reused outbound connections or proxies.
- The previous helper retried exceptions but did not explicitly create a `certifi`-backed TLS context for GitHub, did not force the required GitHub timeout, and did not recycle the session pool after EOF/SSL/socket failures.
- The previous bulk sync flow also widened failure exposure by re-fetching repository metadata that was already available from the repository listing endpoint.

## 8. Cloud Run TLS risks

- Cloud Run terminates HTTPS/TLS at the Google edge, so the application does not need custom server-side TLS termination inside the container.
- End-to-end HTTP/2 should not be enabled for this service until the container is upgraded for `h2c`; enabling it prematurely would create an avoidable transport mismatch.
- Outbound TLS risk remains tied to the container trust store freshness and dependency/runtime currency, which this hardening batch addresses.

## 9. Fixes applied

- Added a reusable `SSLAdapter` with `ssl.create_default_context(cafile=certifi.where())` and TLS 1.2+ minimum enforcement.
- Added `create_github_session()` with GitHub-specific headers, `Connection: close`, retry policy, and `timeout=(10, 60)`.
- Added session recycling after transient SSL/connection/EOF failures to prevent dead/stale socket reuse.
- Added GitHub metadata caching and rate-limit observability.
- Reduced duplicate GitHub API calls during bulk repository sync by reusing list endpoint metadata.
- Upgraded dependency declarations for network/TLS libraries and removed unused `PyGithub`.
- Hardened the Docker images with explicit CA trust-store installation and updated packaging toolchain.
- Raised the default YenkasaAI access-token lifetime to 24 hours via `ACCESS_TOKEN_TTL_MINUTES=1440`.

## 10. Remaining risks

- Production secrets and env files were not printed or audited line-by-line here, so an actual deploy must ensure no custom CA bundle env vars are injected.
- Real network validation against GitHub, Vertex AI, and Cloud Run egress still depends on post-deploy smoke testing from the live runtime.
- If GitHub usage volume grows materially, the next step should be conditional requests with ETags or a persistent metadata cache rather than only process-local caching.
- If Google later publishes a more specific ECDSA rollout milestone, the deploy checklist should be updated to reference that exact guidance.
