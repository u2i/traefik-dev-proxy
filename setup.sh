#!/usr/bin/env bash
set -eo pipefail

# Traefik Dev Reverse Proxy Setup Script
# This script sets up a complete reverse proxy with SSL support

echo "🚀 Setting up Traefik Dev Reverse Proxy..."
echo

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if mkcert is installed
if ! command -v mkcert >/dev/null 2>&1; then
    echo "📦 Installing mkcert..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install mkcert
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Please install mkcert manually: https://github.com/FiloSottile/mkcert#installation"
        exit 1
    else
        echo "Unsupported OS. Please install mkcert manually."
        exit 1
    fi
fi

# Install local CA
echo "🔐 Installing local CA (may require password)..."
if ! mkcert -CAROOT >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
    sudo mkcert -install
else
    mkcert -install 2>/dev/null || sudo mkcert -install
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p reverse-proxy/certs

# Create Docker network
echo "🌐 Creating Docker network 'devnet'..."
docker network create devnet 2>/dev/null || echo "✓ Network already exists"

# Generate SSL certificates
echo "🔒 Generating SSL certificates..."
cd reverse-proxy/certs
if [[ ! -f _wildcard.localhost+3.pem ]]; then
    mkcert "*.localhost" localhost 127.0.0.1 ::1
else
    echo "✓ Certificates already exist"
fi
cd ../..

# Create dynamic.yml
echo "📝 Creating Traefik dynamic configuration..."
cat > reverse-proxy/dynamic.yml << 'EOF'
tls:
  certificates:
    - certFile: /etc/traefik/certs/_wildcard.localhost+3.pem
      keyFile: /etc/traefik/certs/_wildcard.localhost+3-key.pem
EOF

# Create compose.yml
echo "📝 Creating Traefik compose configuration..."
cat > reverse-proxy/compose.yml << 'EOF'
services:
  traefik:
    image: traefik:v3
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entryPoints.web.address=:8080
      - --entryPoints.websecure.address=:8443
      - --providers.file.directory=/etc/traefik/dynamic
    ports:
      - "127.0.0.1:${DEV_PROXY_PORT-8080}:8080"
      - "127.0.0.1:${DEV_PROXY_TLS_PORT-8443}:8443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./certs:/etc/traefik/certs:ro
      - ./dynamic.yml:/etc/traefik/dynamic/dynamic.yml:ro
    networks: [devnet]

networks:
  devnet:
    external: true
EOF

# Create start script
echo "📝 Creating helper scripts..."
cat > start.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail
DEV_PROXY_PORT=${DEV_PROXY_PORT:-8080} docker compose -f reverse-proxy/compose.yml up -d
echo "✅ Traefik proxy started on:"
echo "   HTTP:  http://localhost:8080"
echo "   HTTPS: https://localhost:8443"
EOF
chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail
docker compose -f reverse-proxy/compose.yml down
echo "✅ Traefik proxy stopped"
EOF
chmod +x stop.sh

# Create status script
cat > status.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail
docker compose -f reverse-proxy/compose.yml ps
EOF
chmod +x status.sh

# Create README
cat > README.md << 'EOF'
# Traefik Dev Reverse Proxy

Run multiple apps on localhost without port conflicts using hostname-based routing.

## Quick Start

```bash
# One-time setup
curl -sSL https://gist.github.com/pinetops/113a44fff78736ab36cb4dc35af28135/raw/setup.sh | bash

# Or download first
curl -O https://gist.github.com/pinetops/113a44fff78736ab36cb4dc35af28135/raw/setup.sh
bash setup.sh

# Start/stop
./start.sh
./stop.sh
./status.sh
```

## Usage

Apps accessible via:
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
EOF

# Start the proxy
echo "🚀 Starting Traefik proxy..."
DEV_PROXY_PORT=8080 docker compose -f reverse-proxy/compose.yml up -d

echo
echo "✅ Setup complete!"
echo
echo "Available commands:"
echo "  ./start.sh   - Start the proxy"
echo "  ./stop.sh    - Stop the proxy"
echo "  ./status.sh  - Check proxy status"
echo
echo "Your apps will be accessible at:"
echo "  HTTP:  http://<app>.localhost:8080"
echo "  HTTPS: https://<app>.localhost:8443"
echo
