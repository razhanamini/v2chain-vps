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
INSTALL_DIR="$HOME/v2chain-vps"
API_PORT="5000"
XRAY_VERSION="26.2.4"

fix_docker_paths() {
  print_status "Fixing Docker volume paths..."

  local DATA_DIR="$INSTALL_DIR/xray-data"
  mkdir -p "$DATA_DIR"

  # Replace /var/lib/xray with local writable directory
  if grep -q "/var/lib/xray" "$INSTALL_DIR/docker-compose.yml"; then
    sed -i "s|/var/lib/xray|$DATA_DIR|g" "$INSTALL_DIR/docker-compose.yml"
    print_success "Docker volumes patched to use $DATA_DIR"
  else
    print_success "No restricted paths detected"
  fi
}


# Generate a random API token
generate_token() {
  if command -v openssl > /dev/null 2>&1; then
    openssl rand -hex 32
  else
    # Fallback if openssl is not available
    echo "fallback-token-$(date +%s)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)"
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

# Setup Docker permissions
setup_docker_permissions() {
  print_status "Setting up Docker permissions..."
  
  # Check if user is in docker group
  if id -nG "$USER" | grep -qw docker; then
    print_success "User already in docker group"
    return 0
  fi
  
  print_warning "Adding user to docker group..."
  sudo usermod -aG docker "$USER"
  
  print_warning "You need to log out and back in for changes to take effect."
  print_warning "Alternatively, you can run: newgrp docker"
  
  read -p "Apply group changes now? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Try to apply group changes
    if newgrp docker <<< "echo 'Docker group applied'" 2>/dev/null; then
      print_success "Docker group applied successfully"
    else
      print_warning "Could not apply group changes immediately. Please log out and back in."
    fi
  fi
  
  return 0
}

# Check if Docker daemon is accessible
check_docker_access() {
  if docker info > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Install Docker automatically
install_docker() {
  print_status "Installing Docker..."
  
  # Detect OS
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
  else
    print_error "Cannot detect OS"
    exit 1
  fi
  
  case $OS in
    ubuntu|debian)
      print_status "Detected Ubuntu/Debian system"
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
      curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$OS $(lsb_release -cs) stable"
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    centos|rhel|fedora)
      print_status "Detected CentOS/RHEL/Fedora system"
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      ;;
    *)
      print_error "Unsupported OS: $OS"
      exit 1
      ;;
  esac
  
  # Add user to docker group
  sudo usermod -aG docker "$USER"
  print_success "Docker installed"
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
  
  # Check Docker Compose (or Docker Compose Plugin)
  if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    missing+=("docker-compose")
  fi
  
  if [ ${#missing[@]} -gt 0 ]; then
    print_error "Missing dependencies: ${missing[*]}"
    
    for dep in "${missing[@]}"; do
      case $dep in
        git)
          print_status "Installing Git..."
          sudo apt-get install -y git 2>/dev/null || sudo yum install -y git 2>/dev/null
          ;;
        docker)
          read -p "Install Docker automatically? (y/n): " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker
          else
            print_error "Docker is required. Please install it manually."
            exit 1
          fi
          ;;
        docker-compose)
          print_status "Installing Docker Compose..."
          if command -v docker &> /dev/null && docker compose version &> /dev/null; then
            print_success "Docker Compose plugin already available"
          else
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
              -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
          fi
          ;;
      esac
    done
  fi
  
  # Check Docker permissions
  if ! check_docker_access; then
    setup_docker_permissions
    
    # Check again
    if ! check_docker_access; then
      print_warning "Still cannot access Docker. Trying with sudo..."
      if sudo docker info > /dev/null 2>&1; then
        print_warning "Docker accessible with sudo. Some operations may require sudo."
      else
        print_error "Cannot access Docker daemon. Please ensure Docker is running and permissions are set."
        exit 1
      fi
    fi
  fi
  
  print_success "All dependencies satisfied"
}

install_xray() {
  print_status "Installing Xray $XRAY_VERSION..."

  # Ensure unzip exists
  if ! command -v unzip &> /dev/null; then
    print_status "Installing unzip..."
    sudo apt-get install -y unzip 2>/dev/null || sudo yum install -y unzip 2>/dev/null
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
  if xray version | grep -q "$XRAY_VERSION"; then
    print_success "Xray $XRAY_VERSION installed successfully"
  else
    print_warning "Xray installed but version check failed"
  fi

  # Cleanup
  cd /
  rm -rf "$TEMP_DIR"
}

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

setup_xray_config() {
  print_status "Setting up Xray configuration files..."

  mkdir -p ~/xray/configs

  ln /usr/local/etc/xray/config.json  ~/xray/configs/config.json  
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
}

# Build Docker image
build_image() {
  print_status "Building Docker image..."
  cd "$INSTALL_DIR"
  
  # Check if we can access Docker
  if check_docker_access; then
    if docker-compose build --no-cache; then
      print_success "Docker image built successfully"
    else
      print_warning "Failed to build with docker-compose, trying with sudo..."
      if sudo docker-compose build --no-cache; then
        print_success "Docker image built with sudo"
      else
        print_error "Failed to build Docker image"
        exit 1
      fi
    fi
  elif sudo docker info > /dev/null 2>&1; then
    print_warning "Building with sudo..."
    if sudo docker-compose build --no-cache; then
      print_success "Docker image built with sudo"
    else
      print_error "Failed to build Docker image"
      exit 1
    fi
  else
    print_error "Cannot access Docker daemon"
    exit 1
  fi
}

configure_docker_dns() {
  print_status "Configuring Docker DNS..."

  sudo mkdir -p /etc/docker

  sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF

  # Try to restart Docker in multiple environments
  if command -v systemctl > /dev/null 2>&1; then
    sudo systemctl restart docker 2>/dev/null || true
  fi

  if command -v service > /dev/null 2>&1; then
    sudo service docker restart 2>/dev/null || true
  fi

  if command -v snap > /dev/null 2>&1 && snap list docker >/dev/null 2>&1; then
    sudo snap restart docker 2>/dev/null || true
  fi

  print_success "Docker DNS configured"
}


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
  sudo chown -R "$USER:$USER" /etc/xray /usr/local/etc/xray /var/lib/xray
  sudo chmod 755 /etc/xray /usr/local/etc/xray /var/lib/xray

  print_success "Xray config ready"
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

# Start services
start_services() {
  print_status "Starting services..."
  cd "$INSTALL_DIR"
  
  # Stop if already running
  docker-compose down 2>/dev/null || sudo docker-compose down 2>/dev/null || true
  
  # Start services
  if check_docker_access; then
    docker-compose up -d
  else
    sudo docker-compose up -d
  fi
  
  # Wait for service to start
  print_status "Waiting for service to start..."
  for i setup_xray_dirsin {1..10}; do
    if curl -s "http://localhost:$API_PORT/health" > /dev/null 2>&1; then
      print_success "Service is running!"
      return 0
    fi
    echo -n "."
    sleep 2
  done
  
  print_warning "Service might be slow to start. Checking container status..."
  
  # Check container status
  if check_docker_access; then
    docker-compose ps
  else
    sudo docker-compose ps
  fi
  
  print_warning "If the service is not running, check logs with: docker-compose logs"
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
  echo "📊 Service Information:"
  echo "   Health Check: http://localhost:$API_PORT/health"
  echo "   API Base URL: http://localhost:$API_PORT/api/xray"
  echo "   API Token: $api_token"
  echo ""
  echo "🔧 Management Commands:"
  echo "   View logs:     cd $INSTALL_DIR && docker-compose logs -f"
  echo "   Stop service:  cd $INSTALL_DIR && docker-compose down"
  echo "   Start service: cd $INSTALL_DIR && docker-compose up -d"
  echo "   Restart:       cd $INSTALL_DIR && docker-compose restart"
  echo ""
  echo "📝 Quick Test:"
  echo "   curl http://localhost:$API_PORT/health"
  echo "   curl -H 'x-api-token: $api_token' http://localhost:$API_PORT/api/xray/config"
  echo ""
  echo "💾 Configuration file: $INSTALL_DIR/.env"
  echo ""
  echo "⚠️  Note: If you had Docker permission issues, you may need to:"
  echo "       1. Log out and back in"
  echo "       2. Or run: newgrp docker"
  echo ""
}


create_initial_config() {
  print_status "Creating initial Xray configuration..."
  
  # Create directories
  sudo mkdir -p /etc/xray /usr/local/etc/xray /var/lib/xray
  
  # Create config if it doesn't exist
  if [ ! -f /etc/xray/config.json ]; then
    print_status "Creating /etc/xray/config.json..."
    
    # Create config (simplified version)
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



# Main installation flow
main() {
  echo -e "${GREEN}Starting Xray Manager installation...${NC}"
  
  # Step 1: Check dependencies
  check_deps

  # check docker dns
  configure_docker_dns
  
  # Step 2: Setup Xray directories
  setup_xray_dirs

  create_xray_config

  create_initial_config

  setup_xray_config
  
  # Step 3: Get source code
  get_code

  # fix docker volumes
  fix_docker_paths
  
  # Step 4: Create environment
  create_env
  
  # Step 5: Build Docker image
  build_image
  
  # Step 6: Start services
  start_services
  
  # Step 7: Show success
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

