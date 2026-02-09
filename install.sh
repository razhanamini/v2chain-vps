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
SERVICE_USER="xray-manager"

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
    print_success "Docker installed"
  else
    print_error "Cannot determine OS for Docker installation"
    return 1
  fi
}

check_deps() {
  print_status "Checking dependencies..."
  local missing=()
  for dep in git unzip curl; do
    command -v $dep &>/dev/null || missing+=("$dep")
  done

  if [ ${#missing[@]} -gt 0 ]; then
    print_warning "Missing dependencies: ${missing[*]}"
    for dep in "${missing[@]}"; do
      case $dep in
        git) sudo apt-get install -y git 2>/dev/null || sudo yum install -y git 2>/dev/null ;;
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
  if [ -f "$XRAY_BINARY" ]; then
    CURRENT_VERSION=$("$XRAY_BINARY" version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ "$CURRENT_VERSION" = "$XRAY_VERSION" ]; then
      print_success "Xray $XRAY_VERSION already installed"
      return 0
    fi
  fi
  
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  curl -L -o Xray-linux-64.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
  unzip -q Xray-linux-64.zip
  sudo cp xray "$XRAY_BINARY"
  sudo chmod +x "$XRAY_BINARY"
  sudo chown root:root "$XRAY_BINARY"
  cd /
  rm -rf "$TEMP_DIR"
  print_success "Xray $XRAY_VERSION installed to $XRAY_BINARY"
}

setup_xray_config() {
  print_status "Setting up Xray configuration in $DATA_DIR..."
  sudo mkdir -p "$DATA_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
  sudo chmod 750 "$DATA_DIR"

  if [ ! -f "$XRAY_CONFIG" ]; then
    sudo tee "$XRAY_CONFIG" > /dev/null << 'EOF'
{
  "log": { "loglevel": "warning" },
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" }
  ]
}
EOF
    sudo chown "$SERVICE_USER:$SERVICE_USER" "$XRAY_CONFIG"
    print_success "Default Xray config created"
  else
    print_success "Xray config already exists"
  fi
}

# --------------------------
# Systemd service for Xray
# --------------------------
create_xray_systemd_service() {
  print_status "Creating systemd service for Xray..."
  
  # Create sudoers entry for the service user
  print_status "Setting up passwordless sudo for Xray commands..."
  SUDOERS_FILE="/etc/sudoers.d/xray-manager"
  
  sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
# Allow xray-manager to control Xray service without password
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/systemctl start xray
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/systemctl stop xray
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart xray
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/systemctl status xray
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/systemctl reload xray
$SERVICE_USER ALL=(ALL) NOPASSWD: $XRAY_BINARY
EOF
  
  sudo chmod 440 "$SUDOERS_FILE"
  
  # Create Xray systemd service
  SERVICE_FILE="/etc/systemd/system/xray.service"
  
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=$XRAY_BINARY run -config $XRAY_CONFIG
WorkingDirectory=$DATA_DIR
Restart=on-failure
RestartSec=5
LimitNOFILE=4096

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadOnlyDirectories=/
ReadWriteDirectories=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable xray
  sudo systemctl start xray
  print_success "Xray systemd service installed and started"
}

# --------------------------
# Service user setup with sudo access
# --------------------------
setup_service_user() {
  print_status "Setting up service user..."
  
  if id "$SERVICE_USER" &>/dev/null; then
    print_success "Service user exists"
  else
    sudo useradd --system --create-home --shell /bin/bash "$SERVICE_USER"
    print_success "Service user created"
  fi
  
  # Add user to sudo group
  if ! groups "$SERVICE_USER" | grep -q '\bsudo\b'; then
    sudo usermod -aG sudo "$SERVICE_USER"
    print_success "Added $SERVICE_USER to sudo group"
  fi
}

# --------------------------
# Node.js installation
# --------------------------
install_node() {
  print_status "Installing Node.js..."
  if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v | cut -d'v' -f2)
    print_success "Node already installed: v$NODE_VERSION"
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
# Backend setup
# --------------------------
get_code() {
  print_status "Getting source code..."
  if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR" && git pull origin main || print_warning "Using existing code"
  else
    sudo git clone "$REPO_URL" "$INSTALL_DIR"
  fi
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
  sudo chmod 750 "$INSTALL_DIR"
}

create_env() {
  print_status "Creating .env file..."
  API_TOKEN=$(generate_token)
  
  sudo tee "$INSTALL_DIR/.env" > /dev/null <<EOF
API_STATIC_TOKEN=$API_TOKEN
HOST_UID=$(id -u $SERVICE_USER)
HOST_GID=$(id -g $SERVICE_USER)
NODE_ENV=production
XRAY_CONFIG_PATH=$XRAY_CONFIG
XRAY_BINARY_PATH=$XRAY_BINARY
PORT=$API_PORT
EOF
  
  sudo chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/.env"
  sudo chmod 640 "$INSTALL_DIR/.env"
  print_success ".env file created"
  print_warning "API Token: $API_TOKEN"
  print_warning "Save this token for API access!"
}

build_backend() {
  print_status "Building backend..."
  cd "$INSTALL_DIR"
  
  # Switch to service user for npm operations
  sudo -u "$SERVICE_USER" npm ci || sudo -u "$SERVICE_USER" npm install
  sudo -u "$SERVICE_USER" npm run build
  
  print_success "Backend built"
}

create_node_systemd_service() {
  print_status "Creating Node.js systemd service..."
  SERVICE_FILE="/etc/systemd/system/xray-manager.service"
  
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Xray Manager Backend API
After=network.target xray.service
Requires=xray.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node dist/app.js
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/.env

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWriteDirectories=$INSTALL_DIR $DATA_DIR

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
  for i in {1..15}; do
    if curl -s "http://localhost:$API_PORT/health" >/dev/null 2>&1; then
      print_success "Backend running"
      return
    fi
    echo -n "."
    sleep 2
  done
  print_warning "Backend health check timeout. Check logs: sudo journalctl -u xray-manager"
}

show_success() {
  API_TOKEN=$(sudo grep API_STATIC_TOKEN "$INSTALL_DIR/.env" | cut -d= -f2)
  
  echo ""
  echo "🎉 Xray Manager Installation Complete!"
  echo "======================================"
  echo "Backend API: http://localhost:$API_PORT"
  echo "API Token: $API_TOKEN"
  echo ""
  echo "Installation dir: $INSTALL_DIR"
  echo "Xray config: $XRAY_CONFIG"
  echo "Xray binary: $XRAY_BINARY"
  echo ""
  echo "Services:"
  echo "  • Xray: sudo systemctl status xray"
  echo "  • Manager: sudo systemctl status xray-manager"
  echo ""
  echo "Logs:"
  echo "  • Xray: sudo journalctl -u xray -f"
  echo "  • Manager: sudo journalctl -u xray-manager -f"
  echo ""
  echo "IMPORTANT: The Node.js app can now control Xray without password!"
}

# --------------------------
# Main flow
# --------------------------
main() {
  # Check if running as root
  if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
  fi
  
  check_deps
  setup_service_user
  install_xray
  setup_xray_config
  create_xray_systemd_service
  get_code
  install_node
  create_env
  build_backend
  create_node_systemd_service
  start_backend
  show_success
}

trap 'print_warning "Installation interrupted"; exit 1' INT TERM
main "$@"