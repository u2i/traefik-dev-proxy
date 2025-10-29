# Traefik Dev Reverse Proxy

Run multiple apps on localhost without port conflicts using hostname-based routing.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/u2i/traefik-dev-proxy/main/install.sh | bash
```

This installs:
- Executable: `~/.local/bin/traefik-dev-proxy`
- Config: `~/.local/share/traefik-dev-proxy`
- Docker network: `devnet`

## Usage

```bash
traefik-dev-proxy start       # Start the proxy
traefik-dev-proxy stop        # Stop the proxy
traefik-dev-proxy status      # Check status
traefik-dev-proxy logs        # View logs
traefik-dev-proxy uninstall   # Remove completely
```

## Access Your Apps

- `http://app.localhost`
- `http://api.app.localhost` (wildcards work!)
- `http://admin.app.localhost`

**Note**: HTTP-only (no HTTPS) because browsers don't support wildcard `*.localhost` certificates. For 99% of local dev, HTTP is fine.

## App Configuration

In your `docker-compose.yml`:

```yaml
services:
  app:
    networks: [appnet, devnet]
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=devnet"
      - "traefik.http.routers.${COMPOSE_PROJECT_NAME}.rule=Host(\`${APP_HOSTNAME}\`) || HostRegexp(\`{subdomain:[a-zA-Z0-9-]+}.${APP_HOSTNAME}\`)"
      - "traefik.http.routers.${COMPOSE_PROJECT_NAME}.entrypoints=web"
      - "traefik.http.services.${COMPOSE_PROJECT_NAME}.loadbalancer.server.port=4000"

networks:
  devnet:
    external: true
```

In `.env.dev`:
```
COMPOSE_PROJECT_NAME=myapp
APP_HOSTNAME=myapp.localhost
```

## Features

✅ Single command install
✅ Wildcard subdomain support
✅ No port conflicts between apps
✅ Auto-resolving `.localhost` domains
✅ Clean uninstall

## Requirements

- Docker
- macOS or Linux

## Troubleshooting

### Port 80 already in use

If port 80 is taken, you can use a different port:
```bash
DEV_PROXY_PORT=8080 traefik-dev-proxy start
```

Then access apps at `http://app.localhost:8080`

### 404 Not Found

Check that:
1. Your app is running and on the `devnet` network
2. The Traefik labels are correct in your docker-compose.yml
3. `APP_HOSTNAME` matches what you're accessing (e.g., `myapp.localhost`)
