FROM alpine:3.22

RUN apk add --no-cache bash curl ca-certificates docker-cli jq \
    && ARCH="$(uname -m)" \
    && case "$ARCH" in \
         x86_64) CF_ARCH=amd64 ;; \
         aarch64) CF_ARCH=arm64 ;; \
         *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
       esac \
    && curl -fsSL \
       "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
       -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

COPY start-tunnel.sh /usr/local/bin/start-tunnel.sh
RUN chmod +x /usr/local/bin/start-tunnel.sh

ENTRYPOINT ["/usr/local/bin/start-tunnel.sh"]

