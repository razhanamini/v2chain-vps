#!/bin/bash
# install.sh - One-command setup for Xray Manager (user-level, read-only safe)

set -e

echo "🚀 Xray Manager - One-Command Installation"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
REPO_URL="https://github.com/razhanamini/v2chain-vps.git"
INSTALL_DIR="/opt/xray-manager"
DATA_DIR="$INSTALL_DIR/data"
API_PORT="5000"
XRAY_VERSION="26.2.4"
XRAY_BINARY="/usr/local/bin/xray"
XRAY_CONFIG="$DATA_DIR/config.json"

# Generate random API token
generate_token() {
  if command -v openssl > /dev/null 2>&1; then
    openssl rand -hex 32
  else
    echo "fallback-token-$(date +%s)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 2>/dev/null || echo "manual-token")"
  fi
}

# Print helpers
print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# --------------------------
# Dependency installation
# --------------------------
install_docker() {
  print_status "Installing Docker..."
  if command -v docker &> /dev/null; then
    print_success "Docker already installed"
    return 0
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
      ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common unzip
        curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$ID $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        ;;
      centos|rhel|fedora)
        sudo yum install -y yum-utils unzip
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
        ;;
      *)
        print_error "Unsupported OS: $ID"
        return 1
        ;;
    esac
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    print_warning "You may need to log out/in for Docker group changes"
    print_success "Docker installed"
  else
    print_error "Cannot determine OS for Docker installation"
    return 1
  fi
}

check_deps() {
  print_status "Checking dependencies..."
  local missing=()
  for dep in git docker unzip curl; do
    command -v $dep &>/dev/null || missing+=("$dep")
  done

  if [ ${#missing[@]} -gt 0 ]; then
    print_warning "Missing dependencies: ${missing[*]}"
    for dep in "${missing[@]}"; do
      case $dep in
        git) sudo apt-get install -y git 2>/dev/null || sudo yum install -y git 2>/dev/null ;;
        docker) read -p "Install Docker automatically? (y/n): " -n 1 -r; echo
                [[ $REPLY =~ ^[Yy]$ ]] && install_docker || { print_error "Docker required"; exit 1; } ;;
        unzip) sudo apt-get install -y unzip 2>/dev/null || sudo yum install -y unzip 2>/dev/null ;;
        curl) sudo apt-get install -y curl 2>/dev/null || sudo yum install -y curl 2>/dev/null ;;
      esac
    done
  fi
  print_success "Dependencies satisfied"
}

# --------------------------
# Install Xray
# --------------------------
install_xray() {
  print_status "Installing Xray $XRAY_VERSION..."
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  curl -L -o Xray-linux-64.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
  unzip -q Xray-linux-64.zip
  sudo cp xray "$XRAY_BINARY"
  sudo chmod +x "$XRAY_BINARY"
  cd /
  rm -rf "$TEMP_DIR"
  print_success "Xray $XRAY_VERSION installed to $XRAY_BINARY"
}

setup_xray_config() {
  print_status "Setting up Xray configuration in $DATA_DIR..."
  mkdir -p "$DATA_DIR"
  chown -R "$USER:$USER" "$DATA_DIR"
  chmod 700 "$DATA_DIR"

  if [ ! -f "$XRAY_CONFIG" ]; then
    cat > "$XRAY_CONFIG" << 'EOF'
{
  "log": { "loglevel": "warning" },
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" }
  ]
}
EOF
    print_success "Default Xray config created"
  else
    print_success "Xray config already exists"
  fi
}

# --------------------------
# User-level Xray service
# --------------------------
create_user_systemd_service() {
  print_status "Creating user-level systemd service for Xray..."
  SERVICE_FILE="$HOME/.config/systemd/user/xray.service"
  mkdir -p "$(dirname "$SERVICE_FILE")"

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Xray service (user)
After=network.target

[Service]
ExecStart=$XRAY_BINARY -config $XRAY_CONFIG
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable xray
  systemctl --user start xray
  loginctl enable-linger $USER
  print_success "User-level Xray service installed and started"
}

# --------------------------
# Node.js installation
# --------------------------
install_node() {
  print_status "Installing Node.js..."
  if command -v node >/dev/null 2>&1; then
    print_success "Node already installed: $(node -v)"
    return
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
      ubuntu|debian)
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        ;;
      centos|rhel|fedora)
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
        ;;
      *)
        print_error "Unsupported OS for Node.js: $ID"; exit 1 ;;
    esac
  else
    print_error "Cannot determine OS for Node installation"; exit 1
  fi
  print_success "Node installed: $(node -v)"
}

# --------------------------
# Service user
# --------------------------
setup_service_user() {
  if id "xray-manager" &>/dev/null; then
    print_success "Service user exists"
  else
    print_status "Creating service user..."
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin xray-manager
    print_success "Service user created"
  fi
}

# --------------------------
# Backend setup
# --------------------------
get_code() {
  print_status "Getting source code..."
  if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR" && git pull origin main || print_warning "Using existing code"
  else
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi
  cd "$INSTALL_DIR"
  sudo chown -R xray-manager:xray-manager "$INSTALL_DIR" 2>/dev/null || true
}

create_env() {
  print_status "Creating .env file..."
  mkdir -p "$INSTALL_DIR"
  API_TOKEN=$(generate_token)
  cat > "$INSTALL_DIR/.env" <<EOF
API_STATIC_TOKEN=$API_TOKEN
HOST_UID=$(id -u)
HOST_GID=$(id -g)
NODE_ENV=production
XRAY_CONFIG_PATH=$XRAY_CONFIG
PORT=$API_PORT
EOF
  print_success ".env file created"
  print_warning "API Token: $API_TOKEN"
}

build_backend() {
  print_status "Building backend..."
  cd "$INSTALL_DIR"
  npm ci || npm install
  npm run build
  print_success "Backend built"
}

create_systemd_service() {
  print_status "Creating Node.js systemd service..."
  SERVICE_FILE="/etc/systemd/system/xray-manager.service"
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Xray Manager Backend
After=network.target

[Service]
Type=simple
User=xray-manager
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node dist/app.js
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable xray-manager
  sudo systemctl restart xray-manager
  print_success "Node service installed and started"
}

start_backend() {
  print_status "Checking backend health..."
  for i in {1..10}; do
    if curl -s "http://localhost:$API_PORT/health" >/dev/null 2>&1; then
      print_success "Backend running"
      return
    fi
    echo -n "."
    sleep 2
  done
  print_warning "Backend may still be starting"
}

show_success() {
  API_TOKEN=$(grep API_STATIC_TOKEN "$INSTALL_DIR/.env" | cut -d= -f2)
  echo ""
  echo "🎉 Xray Manager Installation Complete!"
  echo "Backend: http://localhost:$API_PORT"
  echo "API Token: $API_TOKEN"
  echo "Installation dir: $INSTALL_DIR"
  echo "Xray config: $XRAY_CONFIG"
  echo ""
}

# --------------------------
# Main flow
# --------------------------
main() {
  check_deps
  install_xray
  setup_xray_config
  create_user_systemd_service
  setup_service_user
  get_code
  install_node
  create_env
  build_backend
  create_systemd_service
  start_backend
  show_success
}

trap 'print_warning "Installation interrupted"; exit 1' INT TERM
main "$@"
