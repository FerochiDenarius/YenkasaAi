# Yenkasa Backend Wiring Reference

Last updated: 2026-05-28

## Purpose

This document is the canonical wiring reference for YenkasaAi, the Yenkasa app backend, the store backend, the YME/OIL bridge, and the intelligence layer. Use this file before changing URLs, auth flows, relay targets, or AI integration code.

## Canonical system map

| System | Local source | Runtime target | Public URL / access | Role |
| --- | --- | --- | --- | --- |
| YenkasaAi frontend | `/Users/kofibright/StudioProjects/YenkasaAi` | Flutter apps: macOS, Windows, Android, iOS, Web | local builds | User-facing AI client |
| YenkasaAi backend | `/Users/kofibright/Desktop/yenkasa-ai/backend` | Google Cloud Run service `yenkasa-ai-backend` | `https://yenkasa-ai-backend-496173204476.europe-west1.run.app` | Canonical AI backend |
| Yenkasa app backend | `/Users/kofibright/yenkasaChat/yenkasaChatBackend/RegLoginBackend` | DigitalOcean app | `https://yenkasa-8rjea.ondigitalocean.app` | Social app, auth, feed, live events, YME source |
| Yenkasa store upstream | remote host | upstream commerce API | `http://134.209.182.39:8080` | Store upstream behind the store proxy |
| Yenkasa store SSH access | remote host | direct shell access | `ssh -i /Users/kofibright/Desktop/Safe/DenariusWebsite/denariuskeyssh.txt root@134.209.182.39` | Store server administration |

## YenkasaAi frontend wiring

The frontend in `/Users/kofibright/StudioProjects/YenkasaAi` must treat the Cloud Run backend as the canonical auth, chat, search, health, and session backend.

Canonical runtime target:

- `https://yenkasa-ai-backend-496173204476.europe-west1.run.app`

Relevant frontend config:

- `lib/core/config/app_config.dart`
- `lib/core/network/api_client.dart`
- `lib/features/auth/data/auth_service.dart`
- `lib/features/chat/data/ai_api_service.dart`
- `lib/core/storage/auth_session_storage.dart`

Expected contract from the frontend to the YenkasaAi backend:

- auth login: `POST /api/auth/login`
- auth refresh: `POST /api/auth/refresh`
- auth me: `GET /api/auth/me`
- health: `GET /health`
- chat: `POST /chat`
- search: `POST /search`
- YME memory endpoints: `GET /api/yme/health`, `GET /api/yme/search`, `GET /api/yme/memories`

Important rule:

- The new frontend must not default auth/chat to the DigitalOcean Yenkasa app backend.

## YenkasaAi backend

Canonical backend repo:

- `/Users/kofibright/Desktop/yenkasa-ai/backend`

Canonical deployed service:

- Cloud Run service name: `yenkasa-ai-backend`
- Public URL: `https://yenkasa-ai-backend-496173204476.europe-west1.run.app`

Primary route groups:

- legacy AI: `GET /health`, `POST /chat`, `POST /search`, `POST /ingest`
- auth: `/api/auth/*`
- event ingest: `POST /api/events`, `POST /api/events/ingest`
- YME memory: `/api/yme/*`
- repo intelligence: `/api/repo/*`
- admin intelligence: `/api/admin/*`
- logs and alerts: `/api/logs`, `/api/alerts`

Important backend docs:

- `/Users/kofibright/Desktop/yenkasa-ai/backend/README.md`
- `/Users/kofibright/Desktop/yenkasa-ai/backend/docs/architecture.md`
- `/Users/kofibright/Desktop/yenkasa-ai/backend/docs/deployment.md`
- `/Users/kofibright/Desktop/yenkasa-ai/backend/docs/auth_architecture.md`
- `/Users/kofibright/Desktop/yenkasa-ai/backend/docs/yme_architecture.md`

## Yenkasa app backend

Canonical app backend repo:

- `/Users/kofibright/yenkasaChat/yenkasaChatBackend/RegLoginBackend`

Canonical deployed URL:

- `https://yenkasa-8rjea.ondigitalocean.app`

Responsibilities:

- main Yenkasa social application
- feed, views, chatrooms, communities, profiles, live and livestream features
- YME event source generation
- AI relay source for intelligence events
- store proxy mounting

Important mounted backend routes:

- `GET /health`
- `POST /api/views/:viewId/view`
- `POST /api/ai/chat`
- `GET /api/ai/relay/health`
- `/api/yme/*`
- `/triciabales-api/*`

## Store backend and store proxy

The store layer is not a standalone module inside the main Yenkasa app backend. It is a proxy plus local asset/data layer.

Store proxy facts:

- mounted by the Yenkasa app backend
- proxy prefix: `/triciabales-api`
- upstream base: `TRICIABALES_API_BASE`
- source-coded upstream fallback: `http://134.209.182.39:8080`

Remote store access:

- SSH: `ssh -i /Users/kofibright/Desktop/Safe/DenariusWebsite/denariuskeyssh.txt root@134.209.182.39`

Reference doc:

- `/Users/kofibright/yenkasaChat/yenkasa_knowledge/STORE_PROXY_AND_INTEGRATION.md`

## OIL / intelligence bridge wiring

This document uses "OIL bridge" to mean the event and AI bridge between the Yenkasa app backend and the YenkasaAi backend.

Bridge source code in the Yenkasa app backend:

- relay service: `src/intelligence/services/eventPublisher.service.js`
- AI provider bridge: `src/ai/providers/fastapi.provider.js`
- relay health route: `src/ai/routes/index.js`
- YME publish entrypoint: `src/yme/services/eventPublisher.service.js`

Bridge flow:

1. Social or YME events are generated inside the Yenkasa app backend.
2. `src/yme/services/eventPublisher.service.js` ingests the local YME event.
3. The same publisher maps eligible events to intelligence events.
4. `src/intelligence/services/eventPublisher.service.js` sends them to the YenkasaAi backend.
5. The YenkasaAi backend receives them on `POST /api/events` or `POST /api/events/ingest`.
6. The YenkasaAi backend records the event and asynchronously processes it into YME memory and analytics state.

Bridge auth:

- header: `X-Event-Api-Key`
- app backend envs checked in order:
  - `YENKASA_AI_EVENT_API_KEY`
  - `INTERNAL_PLATFORM_API_KEY`
  - `LOG_INGEST_API_KEY`
- AI backend envs used for verification:
  - `event_ingest_api_key`
  - `internal_platform_api_key`

Bridge operational endpoints:

- Yenkasa app backend relay health: `https://yenkasa-8rjea.ondigitalocean.app/api/ai/relay/health`
- with target probe: `https://yenkasa-8rjea.ondigitalocean.app/api/ai/relay/health?probe=true`

Bridge env vars that matter:

- `YENKASA_AI_ENGINE_URL`
- `YENKASA_AI_ENGINE_API_PREFIX`
- `YENKASA_AI_EVENT_INGEST_URL`
- `YENKASA_AI_EVENT_INGEST_PATH`
- `YENKASA_AI_EVENT_HEALTH_URL`
- `YENKASA_AI_EVENT_HEALTH_PATH`
- `YENKASA_AI_EVENT_API_KEY`

Canonical bridge target:

- `https://yenkasa-ai-backend-496173204476.europe-west1.run.app`

Canonical event ingest path:

- `/api/events`

Canonical legacy AI proxy target paths:

- `/chat`
- `/search`
- `/health`

## Intelligence layer wiring

The YenkasaAi backend runs two layers in one service:

- legacy RAG runtime for `/chat`, `/search`, `/ingest`
- authenticated intelligence runtime for auth, repo intelligence, events, YME, analytics, sessions, and admin features

Relevant runtime groups:

- auth: `/api/auth/*`
- repo intelligence: `/api/repo/*`
- events: `/api/events`, `/api/events/ingest`
- YME memory: `/api/yme/*`
- admin intelligence: `/api/admin/*`

YME memory flow on the AI backend:

1. user or backend event reaches the AI backend
2. event is recorded into the event store
3. background processing derives memories, graph edges, summaries, and embeddings
4. `/chat` retrieves relevant memories and injects them into the prompt context
5. responses and interactions are tracked back into the intelligence runtime

## Known bad targets and bad assumptions

Do not treat these as canonical unless intentionally reintroduced and documented:

- `https://yenkasa-ai-496173204476.europe-west1.run.app`
- `POST /api/auth/token/refresh` on the real Cloud Run backend
- `POST /api/ai/chat` as the primary public chat route for the real Cloud Run backend
- defaulting the frontend auth/chat backend to `https://yenkasa-8rjea.ondigitalocean.app`
- defaulting the app backend FastAPI provider to `/api/ai` when targeting the Cloud Run backend legacy routes

## 2026-05-28 fix summary

Frontend fixes in `/Users/kofibright/StudioProjects/YenkasaAi`:

- unified auth/chat/search/health routing onto `https://yenkasa-ai-backend-496173204476.europe-west1.run.app`
- stopped using the wrong refresh alias as the canonical path
- migrated persisted sessions onto the canonical AI backend origin

Yenkasa app backend fixes in `/Users/kofibright/yenkasaChat/yenkasaChatBackend/RegLoginBackend`:

- changed the intelligence relay default target from `yenkasa-ai` to `yenkasa-ai-backend`
- changed the FastAPI provider default target from `yenkasa-ai` to `yenkasa-ai-backend`
- changed the FastAPI provider default API prefix from `/api/ai` to empty so it calls the Cloud Run legacy routes correctly

## Change safety checklist

Before changing any backend wiring:

1. confirm which repo is being changed
2. confirm the deployed runtime URL
3. confirm the auth refresh route
4. confirm whether the target chat path is `/chat` or `/api/ai/chat`
5. confirm whether the event relay target is `yenkasa-ai-backend`
6. confirm whether `X-Event-Api-Key` is configured on both sides
7. update this document if any canonical URL or route contract changes
