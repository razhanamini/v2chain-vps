#!/bin/bash
# install.sh - One-command setup for Xray Manager

set -e

echo "🚀 Xray Manager - One-Command Installation"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/razhanamini/v2chain-vps.git"
INSTALL_DIR="/opt/xray-manager"
API_PORT="5000"
XRAY_VERSION="26.2.4"

# Generate a random API token
generate_token() {
  if command -v openssl > /dev/null 2>&1; then
    openssl rand -hex 32
  else
    # Fallback if openssl is not available
    echo "fallback-token-$(date +%s)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 2>/dev/null || echo "manual-token-please-change")"
  fi
}

# Print colored message
print_status() {
  echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
  echo -e "${RED}[✗]${NC} $1"
}

# Install Docker (called from check_deps)
install_docker() {
  print_status "Installing Docker..."
  
  # Check if already installed
  if command -v docker &> /dev/null; then
    print_success "Docker already installed"
    return 0
  fi
  
  # Install based on OS
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
      ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$ID $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        ;;
      centos|rhel|fedora)
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
        ;;
      *)
        print_error "Unsupported OS: $ID"
        return 1
        ;;
    esac
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    print_warning "You may need to log out and back in for Docker group changes to take effect"
    
    print_success "Docker installed successfully"
    return 0
  else
    print_error "Cannot determine OS for Docker installation"
    return 1
  fi
}

# Check dependencies
check_deps() {
  print_status "Checking dependencies..."
  
  local missing=()
  
  # Check Git
  if ! command -v git &> /dev/null; then
    missing+=("git")
  fi
  
  # Check Docker
  if ! command -v docker &> /dev/null; then
    missing+=("docker")
  fi
  
  # Check Docker Compose (or Docker Compose plugin)
  if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
    missing+=("docker-compose")
  fi
  
  if [ ${#missing[@]} -gt 0 ]; then
    print_warning "Missing dependencies: ${missing[*]}"
    
    for dep in "${missing[@]}"; do
      case $dep in
        git)
          print_status "Installing Git..."
          sudo apt-get install -y git 2>/dev/null || sudo yum install -y git 2>/dev/null || {
            print_error "Failed to install Git"
            exit 1
          }
          print_success "Git installed"
          ;;
        docker)
          print_warning "Docker is required"
          read -p "Install Docker automatically? (y/n): " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker || {
              print_error "Docker installation failed"
              exit 1
            }
          else
            print_error "Docker is required. Please install it manually."
            exit 1
          fi
          ;;
        docker-compose)
          print_status "Installing Docker Compose..."
          if docker compose version &> /dev/null; then
            print_success "Docker Compose plugin already available"
          else
            # Install Docker Compose standalone
            DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d'"' -f4)
            sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
              -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            print_success "Docker Compose installed"
          fi
          ;;
      esac
    done
  fi
  
  print_success "All dependencies satisfied"
}

# Install Xray
install_xray() {
  print_status "Installing Xray $XRAY_VERSION..."

  # Ensure unzip exists
  if ! command -v unzip &> /dev/null; then
    print_status "Installing unzip..."
    sudo apt-get install -y unzip 2>/dev/null || sudo yum install -y unzip 2>/dev/null || {
      print_error "Failed to install unzip"
      exit 1
    }
  fi

  # Create directories
  sudo mkdir -p /etc/xray /var/lib/xray
  sudo chown -R "$USER:$USER" /etc/xray /var/lib/xray
  sudo chmod 755 /etc/xray /var/lib/xray

  # Download Xray
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR" || exit 1
  print_status "Downloading Xray $XRAY_VERSION..."
  curl -L -o Xray-linux-64.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" || { print_error "Download failed"; exit 1; }

  # Extract
  print_status "Extracting..."
  unzip -q Xray-linux-64.zip || { print_error "Extraction failed"; exit 1; }

  # Install binary
  print_status "Installing binary to /usr/local/bin..."
  sudo cp xray /usr/local/bin/
  sudo chmod +x /usr/local/bin/xray

  # Create default config if missing
  if [ ! -f /etc/xray/config.json ]; then
    print_status "Creating default /etc/xray/config.json..."
    cat > /etc/xray/config.json << 'EOF'
{
  "log": { "loglevel": "warning" },
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" }
  ]
}
EOF
  fi

  # Create systemd service if missing
  if [ ! -f /etc/systemd/system/xray.service ]; then
    print_status "Creating systemd service for Xray..."
    sudo tee /etc/systemd/system/xray.service > /dev/null << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
  fi

  # Enable and start
  print_status "Starting Xray service..."
  sudo systemctl daemon-reload
  sudo systemctl enable xray
  sudo systemctl restart xray

  # Verify
  if xray version 2>/dev/null | grep -q "$XRAY_VERSION"; then
    print_success "Xray $XRAY_VERSION installed successfully"
  else
    print_warning "Xray installed but version check failed"
  fi

  # Cleanup
  cd /
  rm -rf "$TEMP_DIR"
}

# Setup Xray directories
setup_xray_dirs() {
  print_status "Checking Xray installation..."
  if command -v xray &> /dev/null; then
    CURRENT_VERSION=$(xray version 2>/dev/null | grep -oP 'Xray \K[0-9.]+' || echo "unknown")
    if [ "$CURRENT_VERSION" != "$XRAY_VERSION" ]; then
      print_warning "Xray version $CURRENT_VERSION found, upgrading to $XRAY_VERSION"
      install_xray
    else
      print_success "Xray $XRAY_VERSION already installed"
    fi
  else
    print_warning "Xray not found. Installing..."
    install_xray
  fi
}

# Setup Xray config
setup_xray_config() {
  print_status "Setting up Xray configuration files..."

  # Create directories
  sudo mkdir -p /etc/xray /usr/local/etc/xray /var/lib/xray
  
  # Create config file if it doesn't exist
  if [ ! -f /etc/xray/config.json ]; then
    print_status "Creating /etc/xray/config.json..."
    sudo tee /etc/xray/config.json > /dev/null << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    }
  ]
}
EOF
    print_success "Created /etc/xray/config.json"
  else
    print_success "Xray config already exists"
  fi
  
  # Copy to /usr/local/etc/xray for backward compatibility
  sudo cp /etc/xray/config.json /usr/local/etc/xray/config.json 2>/dev/null || true
  
  # Set permissions
  sudo chown -R "$USER:$USER" /etc/xray /usr/local/etc/xray /var/lib/xray 2>/dev/null || true
  sudo chmod 755 /etc/xray /usr/local/etc/xray /var/lib/xray
  sudo chmod 644 /etc/xray/config.json /usr/local/etc/xray/config.json
  
  print_success "Xray config files setup complete"
}

# Clone or update repository
get_code() {
  print_status "Getting source code..."
  
  if [ -d "$INSTALL_DIR" ]; then
    print_status "Updating existing installation..."
    cd "$INSTALL_DIR"
    if git pull origin main; then
      print_success "Repository updated"
    else
      print_warning "Could not update repository, using existing code"
    fi
  else
    print_status "Cloning repository..."
    if git clone "$REPO_URL" "$INSTALL_DIR"; then
      print_success "Repository cloned"
    else
      print_error "Failed to clone repository"
      exit 1
    fi
  fi
  
  cd "$INSTALL_DIR"
  sudo chown -R xray-manager:xray-manager "$INSTALL_DIR" 2>/dev/null || true
}

# Create Xray config
create_xray_config() {
  print_status "Ensuring Xray config exists..."
  
  # Create directories
  sudo mkdir -p /etc/xray /usr/local/etc/xray /var/lib/xray
  
  # Create default config if missing
  if [ ! -f /etc/xray/config.json ]; then
    print_status "Creating default /etc/xray/config.json..."
    sudo tee /etc/xray/config.json > /dev/null << 'EOF'
{
  "log": { "loglevel": "warning" },
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" }
  ]
}
EOF
  else
    print_status "Xray config already exists"
  fi

  # Symlink for Docker if needed
  sudo ln -sf /etc/xray/config.json /usr/local/etc/xray/config.json 2>/dev/null || true

  # Set permissions
  sudo chown -R "$USER:$USER" /etc/xray /usr/local/etc/xray /var/lib/xray 2>/dev/null || true
  sudo chmod 755 /etc/xray /usr/local/etc/xray /var/lib/xray

  print_success "Xray config ready"
}

# Install Node.js
install_node() {
  print_status "Installing Node.js..."

  if command -v node >/dev/null 2>&1; then
    print_success "Node already installed: $(node -v)"
    return
  fi

  # Check OS for Node installation
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
        print_error "Unsupported OS for automatic Node installation: $ID"
        print_warning "Please install Node.js 20.x manually"
        exit 1
        ;;
    esac
  else
    print_error "Cannot determine OS for Node installation"
    exit 1
  fi

  print_success "Node installed: $(node -v)"
}

# Build backend
build_backend() {
  print_status "Building backend..."

  cd "$INSTALL_DIR"

  # Check if package.json exists
  if [ ! -f package.json ]; then
    print_error "package.json not found in $INSTALL_DIR"
    exit 1
  fi

  # Install dependencies
  if npm ci; then
    print_success "Dependencies installed"
  else
    print_warning "npm ci failed, trying npm install..."
    npm install || {
      print_error "Failed to install dependencies"
      exit 1
    }
  fi

  # Build
  if npm run build; then
    print_success "Backend built"
  else
    print_error "Build failed"
    exit 1
  fi
}

# Create service user (renamed to avoid duplicate function)
setup_service_user() {
  if id "xray-manager" &>/dev/null; then
    print_success "Service user exists"
  else
    print_status "Creating service user..."
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin xray-manager || {
      print_error "Failed to create service user"
      exit 1
    }
    print_success "Service user created"
  fi
}

# Create systemd service
create_systemd_service() {
  print_status "Creating systemd service..."

  # Ensure directory exists with correct permissions
  sudo mkdir -p "$INSTALL_DIR"
  sudo chown -R xray-manager:xray-manager "$INSTALL_DIR" 2>/dev/null || true
  sudo chmod 755 "$INSTALL_DIR"

  sudo tee /etc/systemd/system/xray-manager.service > /dev/null << EOF
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

Environment=NODE_ENV=production
Environment=PORT=$API_PORT

# security hardening
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

  print_success "Service installed and started"
}

# Start backend and check health
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

  print_warning "Backend might still be starting"
}

# Create environment file
create_env() {
  print_status "Creating configuration..."
  
  local api_token
  api_token=$(generate_token)
  
  cat > "$INSTALL_DIR/.env" << EOF
# Xray Manager Configuration
API_STATIC_TOKEN=$api_token
HOST_UID=$(id -u)
HOST_GID=$(id -g)
NODE_ENV=production
EOF
  
  print_success "Configuration created"
  print_warning "API Token: $api_token"
  echo "  Save this token for API authentication!"
}

# Create initial config (simplified version)
create_initial_config() {
  print_status "Creating initial Xray configuration..."
  
  # Create directories
  sudo mkdir -p /etc/xray /usr/local/etc/xray /var/lib/xray
  
  # Create config if it doesn't exist
  if [ ! -f /etc/xray/config.json ]; then
    print_status "Creating /etc/xray/config.json..."
    
    sudo tee /etc/xray/config.json > /dev/null << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    }
  ]
}
EOF
    
    print_success "Created basic Xray config"
  else
    print_success "Xray config already exists"
  fi
  
  # Create symlink
  sudo ln -sf /etc/xray/config.json /usr/local/etc/xray/config.json 2>/dev/null || true
  
  # Set permissions
  sudo chown -R "$USER:$USER" /etc/xray /usr/local/etc/xray /var/lib/xray 2>/dev/null || true
  sudo chmod 755 /etc/xray /usr/local/etc/xray /var/lib/xray
  
  print_success "Xray directories and config setup complete"
}

# Show success message
show_success() {
  local api_token
  if [ -f "$INSTALL_DIR/.env" ]; then
    api_token=$(grep API_STATIC_TOKEN "$INSTALL_DIR/.env" | cut -d= -f2)
  else
    api_token="[NOT FOUND - check .env file]"
  fi
  
  echo ""
  echo "🎉 Xray Manager Installation Complete!"
  echo "======================================"
  echo ""
  echo "📊 Backend API: http://localhost:$API_PORT"
  echo "🔑 API Token: $api_token"
  echo "📁 Installation directory: $INSTALL_DIR"
  echo ""
  echo "📋 Next steps:"
  echo "   1. Save your API token: $api_token"
  echo "   2. Access the dashboard at http://your-server-ip:$API_PORT"
  echo "   3. Check logs: sudo journalctl -u xray-manager -f"
  echo "   4. Check Xray: sudo systemctl status xray"
  echo ""
}

# Main installation flow
main() {
  echo -e "${GREEN}Starting Xray Manager installation...${NC}"
  
  # Step 1: Check dependencies
  check_deps
  
  # Step 2: Setup Xray
  setup_xray_dirs
  create_xray_config
  create_initial_config
  setup_xray_config
  
  # Step 3: Setup service user
  setup_service_user
  
  # Step 4: Get source code
  get_code
  
  # Step 5: Install Node
  install_node
  
  # Step 6: Create environment
  create_env
  
  # Step 7: Build backend
  build_backend
  
  # Step 8: Create systemd service
  create_systemd_service
  
  # Step 9: Start backend
  start_backend
  
  # Step 10: Show success
  show_success
  
  echo -e "${GREEN}Installation completed successfully!${NC}"
}

# Handle script interruption
cleanup() {
  print_warning "Installation interrupted"
  exit 1
}

trap cleanup INT TERM

# Run installation
main "$@"