FROM ghcr.io/searxng/base:searxng-builder AS builder

COPY ./requirements.txt ./requirements.txt

RUN apk add --no-cache \
    curl \
    nginx \
    openssl \
    tor

RUN --mount=type=cache,id=pip,target=/root/.cache/pip python -m venv ./venv \
 && . ./venv/bin/activate \
 && pip install -r requirements.txt \
 && pip install "uwsgi~=2.0"

COPY ./searx/ ./searx/

ARG TIMESTAMP_SETTINGS="0"

RUN python -m compileall -q searx \
 && touch -c --date=@$TIMESTAMP_SETTINGS ./searx/settings.yml \
 && find ./searx/static \
    \( -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.svg" -o -name "*.ttf" -o -name "*.eot" \) \
    -type f -exec gzip -9 -k {} + -exec brotli --best {} +

FROM ghcr.io/searxng/base:searxng AS dist

ARG LABEL_DATE="0001-01-01T00:00:00Z"
ARG GIT_URL="unspecified"
ARG SEARXNG_GIT_VERSION="unspecified"
ARG LABEL_VCS_REF="unspecified"
ARG LABEL_VCS_URL="unspecified"

COPY torrc /etc/tor/torrc
COPY searxng-nginx.conf /etc/nginx/http.d/default.conf
COPY --chmod=0700 generate_self-signed_cert.sh /usr/local/searxng/generate_self-signed_cert.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY --chmod=0700 searxng-monitor.sh /usr/local/searxng/searxng-monitor.sh

COPY --chown=searxng:searxng --from=builder /usr/local/searxng/venv/ ./venv/
COPY --chown=searxng:searxng --from=builder /usr/local/searxng/searx/ ./searx/
COPY --chown=searxng:searxng ./container/config/ ./.template/
COPY --chown=searxng:searxng ./container/entrypoint.sh ./entrypoint.sh

COPY --from=builder /usr/bin/curl /usr/bin/curl
COPY --from=builder /usr/lib/libcurl.so* /usr/lib/
COPY --from=builder /lib/libssl.so* /lib/
COPY --from=builder /lib/libcrypto.so* /lib/
COPY --from=builder /lib/libz.so* /lib/
COPY --from=builder /usr/lib/libcares.so.2 /usr/lib/
COPY --from=builder /usr/lib/libnghttp2.so.14 /usr/lib/
COPY --from=builder /usr/lib/libpsl.so.5 /usr/lib/
COPY --from=builder /usr/lib/libzstd.so.1 /usr/lib/
COPY --from=builder /usr/lib/libbrotlidec.so.1 /usr/lib/
COPY --from=builder /usr/lib/libbrotlicommon.so.1 /usr/lib/

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /lib/libpcre.so* /lib/
COPY --from=builder /lib/libcrypt.so* /lib/
COPY --from=builder /lib/libdl.so* /lib/
COPY --from=builder /lib/libz.so* /lib/

RUN mkdir -p /var/lib/nginx/logs
RUN mkdir -p /var/lib/nginx/tmp/client_body
RUN mkdir /run/nginx
COPY --from=builder /etc/nginx/mime.types /etc/nginx/mime.types

COPY --from=builder /usr/bin/openssl /usr/bin/openssl

COPY --from=builder /usr/bin/tor /usr/bin/tor
COPY --from=builder /usr/lib/libevent* /usr/lib/
COPY --from=builder /lib/libssl.so* /lib/
COPY --from=builder /lib/libcrypto.so* /lib/
COPY --from=builder /lib/libz.so* /lib/
COPY --from=builder /usr/lib/libseccomp.so.2 /usr/lib/
COPY --from=builder /usr/lib/libcap.so.2 /usr/lib/

ARG TIMESTAMP_UWSGI="0"

RUN touch -c --date=@$TIMESTAMP_UWSGI ./.template/uwsgi.ini

LABEL org.opencontainers.image.authors="searxng <$GIT_URL>" \
      org.opencontainers.image.created="$LABEL_DATE" \
      org.opencontainers.image.description="A privacy-respecting, hackable metasearch engine" \
      org.opencontainers.image.documentation="https://github.com/searxng/searxng-docker" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.revision="$LABEL_VCS_REF" \
      org.opencontainers.image.source="$LABEL_VCS_URL" \
      org.opencontainers.image.title="searxng" \
      org.opencontainers.image.url="$LABEL_VCS_URL" \
      org.opencontainers.image.version="$SEARXNG_GIT_VERSION"

ENV SEARXNG_VERSION="$SEARXNG_GIT_VERSION" \
    INSTANCE_NAME="SearXNG" \
    AUTOCOMPLETE="" \
    BASE_URL="" \
    BIND_ADDRESS="127.0.0.1:8080" \
    SEARXNG_SETTINGS_PATH="$CONFIG_PATH/settings.yml" \
    UWSGI_SETTINGS_PATH="$CONFIG_PATH/uwsgi.ini" \
    UWSGI_WORKERS="%k" \
    UWSGI_THREADS="4"

ENV CONFIG_PATH=/etc/searxng
ENV DATA_PATH=/var/lib/searxng

VOLUME $CONFIG_PATH
VOLUME $DATA_PATH

EXPOSE 80
EXPOSE 443

HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/searxng/entrypoint.sh"]
