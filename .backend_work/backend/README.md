# YenkasaAI FastAPI backend

This directory contains the FastAPI service, its authenticated repository-intelligence API, the RAG runtime, and the Redis-backed ingestion worker.

## Requirements

- Python 3.12
- MongoDB for authenticated intelligence data
- Redis for repository-ingestion jobs
- Google Application Default Credentials for Vertex AI chat and embeddings

The direct dependencies are pinned in [`requirements.txt`](requirements.txt). The development requirements file intentionally delegates to that same lock file so local and CI installs use the same versions.

## Local setup

From this directory:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
cp .env.example .env
```

Edit `.env` with the MongoDB, Redis, Google Cloud, CORS, and JWT values for your environment. Never commit `.env` or service-account credentials.

The default local process is:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```

Run the ingestion worker in a second terminal when repository jobs are enabled:

```bash
python -m app.workers.rq_worker
```

The API exposes `GET /health` and listens on port `8080` by default.

## Docker Compose

From the repository root:

```bash
cp .env.example .env
docker compose up --build
```

Compose starts the API, ingestion worker, MongoDB, and Redis. The API and worker persist local Chroma/upload state in a named volume. Vertex AI still requires valid Google credentials; configure `GOOGLE_APPLICATION_CREDENTIALS` and mount the credential file according to your deployment environment.

## Testing

The suite uses dependency-injected fakes, so it does not require live MongoDB, Redis, Vertex AI, or Google Cloud credentials:

```bash
python -m pytest -q
```

The suite covers all registered endpoint groups, Pydantic validation, authentication and authorization, normalized errors, rate limits, AI response-shape handling, search mode selection, context ranking, and the conscious-reasoning layer.

## Endpoint groups

- Legacy AI: `GET /health`, `POST /chat`, `POST /search`, `POST /ingest`
- Authentication: `/api/auth/*`
- Repository intelligence: `/api/repo/*`
- Events and admin intelligence: `/api/events`, `/api/admin/*`
