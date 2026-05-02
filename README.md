# dev-tunnel

Local Traefik reverse proxy + Cloudflare Tunnel manager for dev environments.

One CLI for two jobs:
- **Proxy**: run multiple apps on localhost without port conflicts via hostname-based routing.
- **Tunnel**: expose those same apps publicly over HTTPS via a per-developer Cloudflare Tunnel (`<project>.<user>.u2i.me` and `*.<project>.<user>.u2i.me`).

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/u2i/traefik-dev-proxy/main/install.sh | bash
```

This installs:
- Executable: `~/.local/bin/dev-tunnel`
- Config: `~/.local/share/traefik-dev-proxy`
- Docker network: `devnet`

> Already had the older `traefik-dev-proxy` binary? The installer removes it — its commands now live under `dev-tunnel proxy ...`.

## Usage

### Proxy (always available)

```bash
dev-tunnel proxy start       # Start Traefik
dev-tunnel proxy stop        # Stop Traefik
dev-tunnel proxy restart
dev-tunnel proxy status      # Container status
dev-tunnel proxy logs        # Follow logs
```

### Tunnel (requires `cloudflared`, `op`, `jq`, `curl`)

```bash
dev-tunnel setup <user> [project]   # One-time: create CF tunnel, DNS, SSL, save token to 1Password
dev-tunnel start [tunnel-name]      # Start cloudflared (default name: <dirname>-<whoami>)
dev-tunnel stop  [tunnel-name]
dev-tunnel status [tunnel-name]
```

### Combined

```bash
dev-tunnel up      # proxy start + tunnel start
dev-tunnel down    # tunnel stop + proxy stop
```

### Other

```bash
dev-tunnel uninstall   # Removes proxy install. Cloudflare tunnels & 1Password items left intact.
```

## Access Your Apps

**Locally:**
- `http://app.localhost:8080`
- `http://api.app.localhost:8080` (wildcards work)

**Externally** (after `dev-tunnel setup tom`):
- `https://<project>.tom.u2i.me`
- `https://<service>.<project>.tom.u2i.me`

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

To also match the tunnel hostname, add `|| HostRegexp(\`^.+\.u2i\.me$\`)` to the router rule and rewrite the Host header in middleware (see e.g. `teamology/compose/compose.dev.local.yml`).

## Requirements

- Docker (always)
- `cloudflared`, `op` (1Password CLI), `jq`, `curl` — only for tunnel commands

macOS or Linux.

## Troubleshooting

### Port 8080 already in use

```bash
DEV_PROXY_PORT=9090 dev-tunnel proxy start
```

Then access apps at `http://app.localhost:9090`.

### 404 Not Found

Check that:
1. Your app is running and on the `devnet` network
2. The Traefik labels are correct in your `docker-compose.yml`
3. `APP_HOSTNAME` matches what you're accessing (e.g., `myapp.localhost`)

### Tunnel error 1033

`cloudflared` daemon isn't running. `dev-tunnel start` (or `dev-tunnel up`) to start it.
