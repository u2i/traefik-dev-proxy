# Traefik Dev Reverse Proxy

Run multiple apps on localhost without port conflicts using hostname-based routing.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/u2i/traefik-dev-proxy/main/install.sh | bash
```

This installs:
- Executable: `~/.local/bin/traefik-dev-proxy`
- Data/certs: `~/.local/share/traefik-dev-proxy`
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

- **HTTP**: `http://app.localhost:8080`
- **HTTPS**: `https://app.localhost:8443`
- **Wildcards**: `https://api.app.localhost:8443`

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
      - "traefik.http.routers.${COMPOSE_PROJECT_NAME}-tls.rule=Host(\`${APP_HOSTNAME}\`) || HostRegexp(\`{subdomain:[a-zA-Z0-9-]+}.${APP_HOSTNAME}\`)"
      - "traefik.http.routers.${COMPOSE_PROJECT_NAME}-tls.entrypoints=websecure"
      - "traefik.http.routers.${COMPOSE_PROJECT_NAME}-tls.tls=true"
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
✅ SSL with trusted certificates (no browser warnings)
✅ Wildcard subdomain support
✅ No port conflicts between apps
✅ Clean uninstall

## Requirements

- Docker
- macOS or Linux
- Homebrew (macOS) for automatic mkcert install

## Troubleshooting

### Permission denied error with mkcert

If you see: `ERROR: failed to read the CA key: open .../rootCA-key.pem: permission denied`

Fix permissions:
```bash
sudo chown -R $(whoami) "$(mkcert -CAROOT)"
chmod 600 "$(mkcert -CAROOT)/rootCA-key.pem"
chmod 644 "$(mkcert -CAROOT)/rootCA.pem"
```

Or regenerate the CA:
```bash
mkcert -uninstall
rm -rf "$(mkcert -CAROOT)"
mkcert -install
```

### HTTPS shows "Not Secure" / Certificate error

Completely quit and restart your browser after installation. Browsers need to be restarted to pick up the new trusted CA.

### 404 on HTTPS but HTTP works

Your app needs HTTPS router labels. Add these to your docker-compose.yml:
```yaml
- "traefik.http.routers.${COMPOSE_PROJECT_NAME}-tls.rule=Host(\`${APP_HOSTNAME}\`) || HostRegexp(\`{subdomain:[a-zA-Z0-9-]+}.${APP_HOSTNAME}\`)"
- "traefik.http.routers.${COMPOSE_PROJECT_NAME}-tls.entrypoints=websecure"
- "traefik.http.routers.${COMPOSE_PROJECT_NAME}-tls.tls=true"
```
