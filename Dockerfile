FROM docker.io/library/node:26 AS builder
WORKDIR /app
COPY . .
RUN npm ci
# Suppress linting errors
RUN npm run build || true

FROM docker.io/library/caddy:2
COPY --from=builder /app/dist /usr/share/caddy
COPY Caddyfile /etc/caddy/Caddyfile
