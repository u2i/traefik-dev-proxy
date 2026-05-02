#!/usr/bin/env bash
set -eo pipefail

# dev-tunnel installer
# Installs to ~/.local/bin with data in ~/.local/share/traefik-dev-proxy

echo "🚀 Installing dev-tunnel..."
echo

BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/traefik-dev-proxy"
RAW_BASE="https://raw.githubusercontent.com/u2i/traefik-dev-proxy/main"

# Resolve where to read source files from. When run from a checkout, use the
# repo. When piped via `curl ... | bash`, BASH_SOURCE points at nothing useful,
# so fall back to downloading from the raw GitHub URL.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$script_dir" ] && [ -f "$script_dir/bin/dev-tunnel" ]; then
    SOURCE_KIND="local"
    REPO_DIR="$script_dir"
else
    SOURCE_KIND="remote"
fi

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Warn (non-fatal) about optional deps used by tunnel commands
for cmd in cloudflared op jq curl; do
    command -v "$cmd" >/dev/null || \
        echo "⚠️  '$cmd' not found — required for 'dev-tunnel setup/start' (proxy commands will still work)."
done

# Create directories
echo "📁 Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$DATA_DIR/config"

# Create Docker network
echo "🌐 Creating Docker network 'devnet'..."
docker network create devnet 2>/dev/null || echo "✓ Network already exists"

# Install files
echo "📝 Installing dev-tunnel..."
if [ "$SOURCE_KIND" = "local" ]; then
    install -m 0755 "$REPO_DIR/bin/dev-tunnel" "$BIN_DIR/dev-tunnel"
    install -m 0644 "$REPO_DIR/config/traefik-compose.yml" "$DATA_DIR/config/compose.yml"
else
    curl -fsSL "$RAW_BASE/bin/dev-tunnel" -o "$BIN_DIR/dev-tunnel"
    chmod 0755 "$BIN_DIR/dev-tunnel"
    curl -fsSL "$RAW_BASE/config/traefik-compose.yml" -o "$DATA_DIR/config/compose.yml"
    chmod 0644 "$DATA_DIR/config/compose.yml"
fi

# Remove legacy traefik-dev-proxy binary if present
if [ -f "$BIN_DIR/traefik-dev-proxy" ]; then
    echo "🧹 Removing legacy 'traefik-dev-proxy' binary (replaced by 'dev-tunnel proxy ...')"
    rm -f "$BIN_DIR/traefik-dev-proxy"
fi

# PATH check
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo
    echo "⚠️  $HOME/.local/bin is not in your PATH"
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo
    echo '  export PATH="$HOME/.local/bin:$PATH"'
fi

# Start the proxy
echo
echo "🚀 Starting Traefik proxy..."
"$BIN_DIR/dev-tunnel" proxy start

echo
echo "✅ Installation complete!"
echo
echo "Installed to:    $BIN_DIR/dev-tunnel"
echo "Data directory:  $DATA_DIR"
echo
echo "Next steps:"
echo "  dev-tunnel help                        # see all commands"
echo "  dev-tunnel setup <user> [project]      # one-time tunnel setup"
echo "  dev-tunnel up                          # start proxy + tunnel"
echo
