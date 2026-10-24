# syntax=docker/dockerfile:1.7

FROM python:3.12-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

RUN python -m venv "$VIRTUAL_ENV" \
    && apt-get update \
    && apt-get install --no-install-recommends -y build-essential gcc g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip \
    && pip install -r requirements.txt

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace \
    PORT=8080 \
    LOCAL_WORKDIR=/var/lib/yenkasa-ai \
    PATH=/opt/venv/bin:$PATH

RUN apt-get update \
    && apt-get install --no-install-recommends -y libgomp1 \
    && groupadd --system --gid 10001 yenkasa \
    && useradd --system --uid 10001 --gid yenkasa --create-home --home-dir /home/yenkasa yenkasa \
    && mkdir -p /workspace /var/lib/yenkasa-ai/chroma_db /var/lib/yenkasa-ai/uploads \
    && chown -R yenkasa:yenkasa /workspace /var/lib/yenkasa-ai /home/yenkasa \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
WORKDIR /workspace

COPY --chown=yenkasa:yenkasa app ./app
COPY --chown=yenkasa:yenkasa api ./api
COPY --chown=yenkasa:yenkasa rag ./rag
COPY --chown=yenkasa:yenkasa services ./services
COPY --chown=yenkasa:yenkasa knowledge ./knowledge

USER yenkasa
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8080/health', timeout=4)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers"]
