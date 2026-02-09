#!/bin/bash
set -e

echo "Xray Manager - Native Production Installer"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/razhanamini/v2chain-vps.git"
INSTALL_DIR="$HOME/v2chain-vps"
API_PORT="5000"
XRAY_VERSION="26.2.4"

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

generate_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    echo "token-$(date +%s)"
  fi
}

install_deps() {
  print_status "Installing system dependencies..."
  sudo apt-get update
  sudo apt-get install -y curl git unzip build-essential
  print_success "Dependencies installed"
}

install_node() {
  print_status "Installing Node.js..."

  if command -v node >/dev/null 2>&1; then
    print_success "Node already installed: $(node -v)"
    return
  fi

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs

  print_success "Node installed: $(node -v)"
}

install_xray() {
  print_status "Installing Xray $XRAY_VERSION..."

  sudo mkdir -p /etc/xray /var/lib/xray

  TMP=$(mktemp -d)
  cd "$TMP"

  curl -L -o xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"

  unzip -q xray.zip
  sudo cp xray /usr/local/bin/
  sudo chmod +x /usr/local/bin/xray

  if [ ! -f /etc/xray/config.json ]; then
    sudo tee /etc/xray/config.json > /dev/null << 'EOF'
{
  "log": { "loglevel": "warning" },
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" }
  ]
}
EOF
  fi

  sudo tee /etc/systemd/system/xray.service > /dev/null << EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable xray
  sudo systemctl restart xray

  cd /
  rm -rf "$TMP"

  print_success "Xray installed"
}

get_code() {
  print_status "Fetching backend code..."

  if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
    git pull
  else
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi

  print_success "Code ready"
}

create_env() {
  print_status "Creating environment file..."

  TOKEN=$(generate_token)

  cat > "$INSTALL_DIR/.env" << EOF
API_STATIC_TOKEN=$TOKEN
NODE_ENV=production
PORT=$API_PORT
EOF

  print_success "Environment created"
  echo "API TOKEN: $TOKEN"
}

build_backend() {
  print_status "Building backend..."
  cd "$INSTALL_DIR"
  npm ci
  npm run build
  print_success "Build complete"
}

create_service_user() {
  print_status "Creating service user..."

  if ! id xray-manager >/dev/null 2>&1; then
    sudo useradd -r -s /bin/false xray-manager
  fi

  sudo chown -R xray-manager:xray-manager "$INSTALL_DIR"
  print_success "User ready"
}

create_systemd_service() {
  print_status "Creating systemd service..."

  sudo tee /etc/systemd/system/xray-manager.service > /dev/null << EOF
[Unit]
Description=Xray Manager Backend
After=network.target

[Service]
Type=simple
User=xray-manager
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=5

EnvironmentFile=$INSTALL_DIR/.env

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable xray-manager
  sudo systemctl restart xray-manager

  print_success "Backend service installed"
}

health_check() {
  print_status "Checking backend health..."

  for i in {1..10}; do
    if curl -s "http://localhost:$API_PORT/health" >/dev/null 2>&1; then
      print_success "Backend running"
      return
    fi
    echo -n "."
    sleep 2
  done

  print_warning "Health check failed"
}

show_success() {
  echo ""
  echo "Installation complete"
  echo ""
  echo "Health endpoint:"
  echo "  http://localhost:$API_PORT/health"
  echo ""
  echo "Logs:"
  echo "  journalctl -u xray-manager -f"
  echo ""
  echo "Restart:"
  echo "  systemctl restart xray-manager"
  echo ""
  echo "Status:"
  echo "  systemctl status xray-manager"
  echo ""
}

main() {
  install_deps
  install_node
  install_xray
  get_code
  create_env
  build_backend
  create_service_user
  create_systemd_service
  health_check
  show_success
}

main "$@"
