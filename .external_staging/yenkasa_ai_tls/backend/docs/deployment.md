# Deployment

## Cloud Run API Service

```bash
gcloud run deploy yenkasa-ai-backend \
  --source . \
  --region europe-west1 \
  --project project-10405180-0afd-4ecc-9f8 \
  --allow-unauthenticated \
  --port 8080 \
  --env-vars-file .env
```

## Cloud Run Worker Service

Deploy the worker from `Dockerfile.worker` so ingestion stays off the request path:

```bash
gcloud run deploy yenkasa-ai-worker \
  --source . \
  --region europe-west1 \
  --project project-10405180-0afd-4ecc-9f8 \
  --no-allow-unauthenticated \
  --env-vars-file .env
```

## Required managed dependencies

- MongoDB Atlas
- Redis instance reachable from Cloud Run
- Google Cloud Storage bucket for the existing Chroma snapshot flow
- Google service account with Vertex AI and GCS permissions
- optional internal log-ingest secret via `LOG_INGEST_API_KEY`

## Recommended environment strategy

- keep `JWT_SECRET_KEY`, `MONGODB_URI`, and `REDIS_URL` in Secret Manager
- keep `LOG_INGEST_API_KEY` in Secret Manager if you want to restrict `/api/logs`
- inject secrets into Cloud Run at deploy time
- set `ACCESS_TOKEN_TTL_MINUTES=1440` for the 24 hour YenkasaAI login window
- keep `REPO_ALLOWED_ROOTS` limited to mounted or copied repository roots
- run the worker with the same Mongo/Redis/JWT environment as the API
- do not set `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, or other custom trust-store variables unless you are intentionally replacing the system trust store
- do not enable Cloud Run `--use-http2` for this service until the container is explicitly upgraded for `h2c`; Cloud Run still terminates HTTPS/TLS at the edge by default

## Local verification

```bash
python3 -m compileall app api services
python3 -m unittest discover -s tests
```
