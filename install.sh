#!/bin/bash
# install.sh - One-command setup for Xray Manager

set -e

echo "🚀 Xray Manager - One-Command Installation"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
  echo -e "${RED}⚠️  Please run as non-root user, not with sudo${NC}"
  exit 1
fi

# Configuration
REPO_URL="https://github.com/razhanamini/v2chain-vps.git"
INSTALL_DIR="$HOME/xray-manager"
API_PORT="5000"

# Generate a random API token
generate_token() {
  openssl rand -hex 32 2>/dev/null || echo "fallback-token-$(date +%s)"
}

# Check dependencies
check_deps() {
  echo "🔍 Checking dependencies..."
  
  local missing=()
  
  # Check Docker
  if ! command -v docker &> /dev/null; then
    missing+=("docker")
  fi
  
  # Check Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    missing+=("docker-compose")
  fi
  
  # Check Git
  if ! command -v git &> /dev/null; then
    missing+=("git")
  fi
  
  # Check Node.js (for building if needed)
  if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠️  Node.js not found (optional for development)${NC}"
  fi
  
  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}"
    echo "Please install:"
    
    for dep in "${missing[@]}"; do
      case $dep in
        docker)
          echo "  Docker: https://docs.docker.com/engine/install/"
          ;;
        docker-compose)
          echo "  Docker Compose: https://docs.docker.com/compose/install/"
          ;;
        git)
          echo "  Git: sudo apt install git"
          ;;
      esac
    done
    
    # Offer to install Docker automatically
    if [[ " ${missing[*]} " == *" docker "* ]]; then
      read -p "Install Docker automatically? (y/n): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_docker
      else
        exit 1
      fi
    else
      exit 1
    fi
  fi
  
  echo -e "${GREEN}✅ All dependencies found${NC}"
}

# Install Docker automatically
install_docker() {
  echo "📦 Installing Docker..."
  
  # Detect OS
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
  else
    OS=$(uname -s)
  fi
  
  case $OS in
    *Ubuntu*|*Debian*)
      sudo apt update
      sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo usermod -aG docker $USER
      ;;
    *CentOS*|*Fedora*|*RHEL*)
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      sudo usermod -aG docker $USER
      ;;
    *)
      echo -e "${RED}❌ Unsupported OS. Please install Docker manually.${NC}"
      exit 1
      ;;
  esac
  
  echo -e "${GREEN}✅ Docker installed${NC}"
  echo "⚠️  Please log out and back in for group changes to take effect, or run:"
  echo "   newgrp docker"
  
  read -p "Continue anyway? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
}

# Setup Xray directories and permissions
setup_xray_dirs() {
  echo "📁 Setting up Xray directories..."
  
  # Create directories if they don't exist
  sudo mkdir -p /etc/xray /var/lib/xray
  
  # Check if Xray is already installed
  if command -v xray &> /dev/null; then
    echo -e "${GREEN}✅ Xray is already installed${NC}"
  else
    echo -e "${YELLOW}⚠️  Xray not found. Please install Xray first.${NC}"
    echo "Quick install:"
    echo "  bash -c \"$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install"
    read -p "Install Xray now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      install_xray
    fi
  fi
  
  # Set permissions
  sudo chown -R $USER:$USER /etc/xray /var/lib/xray 2>/dev/null || true
  sudo chmod 755 /etc/xray /var/lib/xray
  
  echo -e "${GREEN}✅ Directories configured${NC}"
}

# Install Xray
#!/bin/bash
# install.sh - Updated Xray installation with specific version

# ... [previous code remains the same] ...

# Install Xray with specific version (26.2.4)
install_xray() {
  echo "📦 Installing Xray version 26.2.4..."
  
  # Create temporary directory
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  
  # Download the specific version
  echo "Downloading Xray 26.2.4..."
  if ! curl -L -o Xray-linux-64.zip "https://github.com/XTLS/Xray-core/releases/download/v26.2.4/Xray-linux-64.zip"; then
    echo -e "${RED}❌ Failed to download Xray${NC}"
    return 1
  fi
  
  # Extract
  echo "Extracting..."
  unzip -q Xray-linux-64.zip
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to extract Xray${NC}"
    return 1
  fi
  
  # Install
  echo "Installing..."
  sudo systemctl stop xray 2>/dev/null || true
  sudo cp xray /usr/local/bin/
  sudo chmod +x /usr/local/bin/xray
  
  # Create systemd service if it doesn't exist
  if [ ! -f /etc/systemd/system/xray.service ]; then
    echo "Creating systemd service..."
    sudo tee /etc/systemd/system/xray.service > /dev/null << 'EOF'
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
  
  # Create config directory
  sudo mkdir -p /etc/xray
  
  # Create default config if it doesn't exist
  if [ ! -f /etc/xray/config.json ]; then
    echo "Creating default config..."
    sudo tee /etc/xray/config.json > /dev/null << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "api": {
    "tag": "api",
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ]
  },
  "stats": {
    "enabled": true,
    "statsFile": "/var/lib/xray/stats.json"
  },
  "policy": {
    "levels": {
      "0": {
        "handshake": 12,
        "connIdle": 900,
        "downlinkOnly": 20,
        "uplinkOnly": 8,
        "bufferSize": 20480,
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "inbounds": [
    {
      "port": 8445,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "7e64f9bf-d733-4dd0-a642-3a05d1cc3f0e",
            "email": "user1@gmail.com",
            "flow": "",
            "limitIp": 0,
            "totalGB": 100,
            "expireTime": 1772286796225,
            "createdAt": "2026-02-08T13:53:16.225Z"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "play.google.com:443",
          "serverNames": [
            "play.google.com"
          ],
          "privateKey": "KJYm4jdWfD4VNZ5D98qVQ0WwM8BHge8sBpeuEo9ePX0",
          "shortIds": [
            "6ba85179e30d4fc2"
          ],
          "fingerprint": "chrome",
          "spiderX": ""
        },
        "tcpSettings": {
          "header": {
            "type": "none"
          },
          "acceptProxyProtocol": false
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "tag": "vless-reality-inbound"
    },
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 62789,
        "network": "tcp"
      },
      "tag": "api-inbound"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "inboundTag": [
          "api-inbound"
        ],
        "outboundTag": "api",
        "type": "field"
      }
    ]
  }
}
EOF
  fi
  
  # Enable and start service
  sudo systemctl daemon-reload
  sudo systemctl enable xray
  sudo systemctl start xray
  
  # Verify installation
  if /usr/local/bin/xray version | grep -q "26.2.4"; then
    echo -e "${GREEN}✅ Xray 26.2.4 installed successfully${NC}"
  else
    echo -e "${YELLOW}⚠️  Xray installed but version check failed${NC}"
  fi
  
  # Cleanup
  cd /
  rm -rf "$TEMP_DIR"
}

# Alternative method using the official installer with version
install_xray_alternative() {
  echo "📦 Installing Xray 26.2.4 (alternative method)..."
  
  # Download the official installer
  curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh -o /tmp/install-release.sh
  
  # Make it executable
  chmod +x /tmp/install-release.sh
  
  # Install specific version
  sudo bash /tmp/install-release.sh -v v26.2.4
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Xray 26.2.4 installed${NC}"
  else
    echo -e "${RED}❌ Failed to install Xray${NC}"
  fi
  
  # Cleanup
  rm /tmp/install-release.sh
}

# Updated check for Xray with version verification
setup_xray_dirs() {
  echo "📁 Setting up Xray directories..."
  
  # Create directories if they don't exist
  sudo mkdir -p /etc/xray /var/lib/xray
  
  # Check if Xray is already installed and is version 26.2.4
  if command -v xray &> /dev/null; then
    CURRENT_VERSION=$(xray version | grep -oP 'Xray \K[0-9.]+' | head -1)
    if [ "$CURRENT_VERSION" = "26.2.4" ]; then
      echo -e "${GREEN}✅ Xray 26.2.4 is already installed${NC}"
    else
      echo -e "${YELLOW}⚠️  Found Xray version $CURRENT_VERSION, need version 26.2.4${NC}"
      read -p "Upgrade to version 26.2.4? (y/n): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_xray
      fi
    fi
  else
    echo -e "${YELLOW}⚠️  Xray not found. Installing version 26.2.4...${NC}"
    install_xray
  fi
  
  # Set permissions
  sudo chown -R $USER:$USER /etc/xray /var/lib/xray 2>/dev/null || true
  sudo chmod 755 /etc/xray /var/lib/xray
  
  echo -e "${GREEN}✅ Directories configured${NC}"
}

# Clone or update repository
get_code() {
  echo "📥 Getting source code..."
  
  if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull origin main
  else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
  fi
  
  echo -e "${GREEN}✅ Code downloaded${NC}"
}

# Build Docker image
build_image() {
  echo "🐳 Building Docker image..."
  cd "$INSTALL_DIR"
  docker-compose build --no-cache
  echo -e "${GREEN}✅ Image built${NC}"
}

# Create environment file
create_env() {
  echo "⚙️  Creating configuration..."
  
  local api_token=$(generate_token)
  
  cat > "$INSTALL_DIR/.env" << EOF
# Xray Manager Configuration
API_STATIC_TOKEN=$api_token
HOST_UID=$(id -u)
HOST_GID=$(id -g)
NODE_ENV=production
EOF
  
  echo -e "${GREEN}✅ Configuration created${NC}"
  echo -e "${YELLOW}📋 API Token: $api_token${NC}"
  echo "  Save this token for API authentication!"
}

# Start services
start_services() {
  echo "🚀 Starting services..."
  cd "$INSTALL_DIR"
  
  # Stop if already running
  docker-compose down 2>/dev/null || true
  
  # Start services
  docker-compose up -d
  
  # Wait for service to start
  echo "⏳ Waiting for service to start..."
  sleep 5
  
  # Check if running
  if curl -s http://localhost:$API_PORT/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service is running!${NC}"
  else
    echo -e "${YELLOW}⚠️  Service might still be starting...${NC}"
    sleep 5
  fi
  
  echo -e "${GREEN}✅ Installation complete!${NC}"
}

# Show success message
show_success() {
  local api_token=$(grep API_STATIC_TOKEN "$INSTALL_DIR/.env" | cut -d= -f2)
  
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
}

# Main installation flow
main() {
  echo -e "${GREEN}Starting Xray Manager installation...${NC}"
  
  # Step 1: Check dependencies
  check_deps
  
  # Step 2: Setup Xray directories
  setup_xray_dirs
  
  # Step 3: Get source code
  get_code
  
  # Step 4: Create environment
  create_env
  
  # Step 5: Build Docker image
  build_image
  
  # Step 6: Start services
  start_services
  
  # Step 7: Show success
  show_success
}

# Run installation
main "$@"










# single line installation: 
# bash <(curl -sSL https://raw.githubusercontent.com/yourusername/xray-manager/main/scripts/install-xray-version.sh)
