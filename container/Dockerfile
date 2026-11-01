# DorXNG: self-contained Alpine build (Tor + nginx + SearXNG/Granian)
# Upstream's docker.io/searxng/base images ship without a package manager, so
# this image is built from python:alpine instead.

FROM docker.io/library/python:3.14-alpine AS builder

WORKDIR /usr/local/searxng

RUN apk add --no-cache build-base libxml2-dev libxslt-dev libffi-dev brotli

COPY ./requirements.txt ./requirements-server.txt ./

RUN set -eux; \
    python -m venv ./.venv; \
    ./.venv/bin/pip install --no-cache-dir --requirement ./requirements.txt --requirement ./requirements-server.txt; \
    find ./.venv/lib/ -type d -name "__pycache__" -exec rm -rf {} +; \
    python -m compileall -q -f -j 0 --invalidation-mode=unchecked-hash ./.venv/lib/

COPY ./searx/ ./searx/

RUN set -eux; \
    python -m compileall -q -f -j 0 --invalidation-mode=unchecked-hash ./searx/; \
    find ./searx/static/ -type f \
    \( -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.svg" \) \
    -exec gzip -9 -k {} + \
    -exec brotli -9 -k {} +

FROM docker.io/library/python:3.14-alpine AS dist

WORKDIR /usr/local/searxng

RUN set -eux; \
    apk add --no-cache tor nginx openssl curl libxml2 libxslt ca-certificates; \
    addgroup -g 977 searxng; \
    adduser -D -H -u 977 -G searxng -h /usr/local/searxng searxng; \
    mkdir -p /etc/searxng /var/cache/searxng /run/nginx /var/lib/nginx/tmp/client_body /var/lib/nginx/logs

COPY --chown=977:977 --from=builder /usr/local/searxng/.venv/ ./.venv/
COPY --chown=977:977 --from=builder /usr/local/searxng/searx/ ./searx/
COPY --chown=977:977 ./container/entrypoint.sh ./container/settings.template.yml ./
COPY --chown=977:977 ./searx/version_frozen.py ./searx/

COPY ./container/dorxng/torrc /etc/tor/torrc
COPY ./container/dorxng/nginx.conf /etc/nginx/nginx.conf
COPY ./container/dorxng/searxng-nginx.conf /etc/nginx/http.d/default.conf
COPY ./container/dorxng/generate_self-signed_cert.sh ./container/dorxng/searxng-monitor.sh ./
RUN chmod 0700 ./generate_self-signed_cert.sh ./searxng-monitor.sh ./entrypoint.sh

ARG CREATED="0001-01-01T00:00:00Z"
ARG VERSION="unknown"
ARG VCS_URL="unknown"
ARG VCS_REVISION="unknown"

LABEL org.opencontainers.image.created="$CREATED" \
    org.opencontainers.image.description="DorXNG: SearXNG routed over Tor" \
    org.opencontainers.image.documentation="https://github.com/researchanddestroy/dorxng" \
    org.opencontainers.image.licenses="AGPL-3.0-or-later" \
    org.opencontainers.image.revision="$VCS_REVISION" \
    org.opencontainers.image.source="$VCS_URL" \
    org.opencontainers.image.title="DorXNG" \
    org.opencontainers.image.version="$VERSION"

ENV __SEARXNG_VERSION="$VERSION" \
    __SEARXNG_CONFIG_PATH="/etc/searxng" \
    __SEARXNG_DATA_PATH="/var/cache/searxng" \
    __SEARXNG_SETTINGS_PATH="/etc/searxng/settings.yml" \
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" \
    GRANIAN_PROCESS_NAME="searxng" \
    GRANIAN_INTERFACE="wsgi" \
    GRANIAN_HOST="127.0.0.1" \
    GRANIAN_PORT="8080" \
    GRANIAN_WEBSOCKETS="false" \
    GRANIAN_BLOCKING_THREADS="4" \
    GRANIAN_WORKERS_KILL_TIMEOUT="30s" \
    GRANIAN_BLOCKING_THREADS_IDLE_TIMEOUT="5m"

VOLUME /etc/searxng
VOLUME /var/cache/searxng

EXPOSE 80
EXPOSE 443

HEALTHCHECK CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/searxng/entrypoint.sh"]
