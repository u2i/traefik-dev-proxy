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

# Note: We don't use HTTPS because browsers don't support wildcard *.localhost certificates
# HTTP on port 80 works fine for local development

# Create directories
echo "📁 Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$DATA_DIR/config"

# Create Docker network
echo "🌐 Creating Docker network 'devnet'..."
docker network create devnet 2>/dev/null || echo "✓ Network already exists"

# Create compose.yml
echo "📝 Creating Traefik compose configuration..."
cat > "$DATA_DIR/config/compose.yml" << 'EOF'
services:
  traefik:
    image: traefik:v3
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entryPoints.web.address=:80
    ports:
      - "${DEV_PROXY_PORT-80}:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
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
    export DEV_PROXY_PORT=${DEV_PROXY_PORT:-80}
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ Traefik proxy started on:"
    echo "   HTTP: http://localhost:${DEV_PROXY_PORT}"
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
  DEV_PROXY_PORT      HTTP port (default: 80)

Examples:
  traefik-dev-proxy start
  DEV_PROXY_PORT=8080 traefik-dev-proxy start
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
echo "  http://<app>.localhost"
echo
