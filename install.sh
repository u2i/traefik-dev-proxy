#!/usr/bin/env bash
set -eo pipefail

# Traefik Dev Reverse Proxy Installer
# Installs to ~/.local/bin with data in ~/.local/share/traefik-dev-proxy

echo "🚀 Installing Traefik Dev Reverse Proxy..."
echo

BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/traefik-dev-proxy"
INSTALL_NAME="traefik-dev-proxy"

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

# Create directories
echo "📁 Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$DATA_DIR/certs"
mkdir -p "$DATA_DIR/config"

# Create Docker network
echo "🌐 Creating Docker network 'devnet'..."
docker network create devnet 2>/dev/null || echo "✓ Network already exists"

# Generate SSL certificates
echo "🔒 Generating SSL certificates..."
cd "$DATA_DIR/certs"
if [[ ! -f _wildcard.localhost+3.pem ]]; then
    mkcert "*.localhost" localhost 127.0.0.1 ::1
else
    echo "✓ Certificates already exist"
fi

# Create dynamic.yml
echo "📝 Creating Traefik dynamic configuration..."
cat > "$DATA_DIR/config/dynamic.yml" << 'EOF'
tls:
  certificates:
    - certFile: /etc/traefik/certs/_wildcard.localhost+3.pem
      keyFile: /etc/traefik/certs/_wildcard.localhost+3-key.pem
EOF

# Create compose.yml
echo "📝 Creating Traefik compose configuration..."
cat > "$DATA_DIR/config/compose.yml" << 'EOF'
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
      - ${DATA_DIR}/certs:/etc/traefik/certs:ro
      - ${DATA_DIR}/config/dynamic.yml:/etc/traefik/dynamic/dynamic.yml:ro
    networks: [devnet]
    restart: unless-stopped

networks:
  devnet:
    external: true
EOF

# Create the main executable
echo "📝 Creating executable..."
cat > "$BIN_DIR/$INSTALL_NAME" << 'EOFSCRIPT'
#!/usr/bin/env bash
set -eo pipefail

DATA_DIR="$HOME/.local/share/traefik-dev-proxy"
COMPOSE_FILE="$DATA_DIR/config/compose.yml"

cmd_start() {
    echo "🚀 Starting Traefik proxy..."
    export DATA_DIR
    export DEV_PROXY_PORT=${DEV_PROXY_PORT:-8080}
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ Traefik proxy started on:"
    echo "   HTTP:  http://localhost:8080"
    echo "   HTTPS: https://localhost:8443"
}

cmd_stop() {
    echo "🛑 Stopping Traefik proxy..."
    export DATA_DIR
    docker compose -f "$COMPOSE_FILE" down
    echo "✅ Traefik proxy stopped"
}

cmd_restart() {
    cmd_stop
    cmd_start
}

cmd_status() {
    export DATA_DIR
    docker compose -f "$COMPOSE_FILE" ps
}

cmd_logs() {
    export DATA_DIR
    docker compose -f "$COMPOSE_FILE" logs -f
}

cmd_help() {
    cat << EOF
Traefik Dev Reverse Proxy

Usage: traefik-dev-proxy <command>

Commands:
  start       Start the proxy
  stop        Stop the proxy
  restart     Restart the proxy
  status      Show proxy status
  logs        Show proxy logs (follow)
  uninstall   Remove installation
  help        Show this help

Environment variables:
  DEV_PROXY_PORT      HTTP port (default: 8080)
  DEV_PROXY_TLS_PORT  HTTPS port (default: 8443)

Examples:
  traefik-dev-proxy start
  DEV_PROXY_PORT=9090 traefik-dev-proxy start
  traefik-dev-proxy logs
EOF
}

cmd_uninstall() {
    echo "🗑️  Uninstalling Traefik Dev Proxy..."

    # Stop the proxy
    export DATA_DIR
    docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true

    # Remove Docker network
    docker network rm devnet 2>/dev/null || true

    # Remove data directory
    rm -rf "$DATA_DIR"

    # Remove executable
    rm -f "$HOME/.local/bin/traefik-dev-proxy"

    echo "✅ Uninstalled successfully"
    echo "Note: mkcert and its CA are still installed. To remove:"
    echo "  mkcert -uninstall"
}

case "${1:-help}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    uninstall)
        cmd_uninstall
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'traefik-dev-proxy help' for usage"
        exit 1
        ;;
esac
EOFSCRIPT

chmod +x "$BIN_DIR/$INSTALL_NAME"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo
    echo "⚠️  $HOME/.local/bin is not in your PATH"
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo
    echo "Then run: source ~/.zshrc (or ~/.bashrc)"
fi

# Start the proxy
echo
echo "🚀 Starting Traefik proxy..."
"$BIN_DIR/$INSTALL_NAME" start

echo
echo "✅ Installation complete!"
echo
echo "Installed to: $BIN_DIR/$INSTALL_NAME"
echo "Data directory: $DATA_DIR"
echo
echo "Available commands:"
echo "  traefik-dev-proxy start       - Start the proxy"
echo "  traefik-dev-proxy stop        - Stop the proxy"
echo "  traefik-dev-proxy status      - Check proxy status"
echo "  traefik-dev-proxy logs        - Show proxy logs"
echo "  traefik-dev-proxy uninstall   - Remove installation"
echo
echo "Your apps will be accessible at:"
echo "  HTTP:  http://<app>.localhost:8080"
echo "  HTTPS: https://<app>.localhost:8443"
echo
