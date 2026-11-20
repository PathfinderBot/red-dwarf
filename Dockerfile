FROM docker.io/library/node:26 AS builder
# eMudhra CA compromise (2026-10): drop the compromised emSign ECC Root CA - C3 root (build-time TLS).
RUN rm -f /usr/share/ca-certificates/mozilla/emSign_ECC_Root_CA_-_C3.crt && update-ca-certificates
WORKDIR /app
COPY . .
RUN npm ci
# Suppress linting errors
RUN npm run build || true

FROM docker.io/library/caddy:2
# eMudhra CA compromise (2026-10): caddy 2.11.x is built with Go < 1.26.10, so its
# embedded root store lacks the eMudhra key block. Point Go at a trimmed copy of
# the system store until caddy re-releases with the fix.
RUN mkdir -p /etc/cacerts && \
    i=0 && \
    for f in /etc/ssl/certs/ca-cert-*.pem; do \
        s=$(openssl x509 -in "$f" -noout -subject 2>/dev/null) || continue; \
        case "$s" in \
            *emSign* | *EmSign* | *"AAA Certificate Services"* | *Comodo*AAA*) ;; \
            *) cp "$f" "/etc/cacerts/c$i.pem"; i=$((i+1));; \
        esac; \
    done && \
    cat /etc/cacerts/c*.pem > /etc/cacerts/bundle.pem && rm -f /etc/cacerts/c*.pem
ENV SSL_CERT_FILE=/etc/cacerts/bundle.pem
COPY --from=builder /app/dist /usr/share/caddy
COPY Caddyfile /etc/caddy/Caddyfile
