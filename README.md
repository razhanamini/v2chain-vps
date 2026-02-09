




configuration for systemd:


/etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target




/etc/systemd/system/xray-manager.service
[Unit]
Description=Xray Manager API (Root Mode - Simple)
After=network.target xray.service
Wants=network.target

[Service]
Type=simple
# RUN AS ROOT - no permission issues
User=root
Group=root
WorkingDirectory=/opt/xray-manager
ExecStart=/opt/xray-manager/start.sh
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target





XRAY_VERSION="26.2.4"


install xray version specific:
  
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








step by step installatio:




step:1

# Update system
sudo apt update && sudo apt upgrade -y

# Install basic dependencies
sudo apt install -y curl git wget unzip



step:2
# Create all necessary directories
sudo mkdir -p /opt/xray-manager
sudo mkdir -p /etc/xray
sudo mkdir -p /var/lib/xray
sudo mkdir -p /usr/local/etc/xray

# Set permissions
sudo chown -R $USER:$USER /opt/xray-manager
sudo chmod 755 /opt/xray-manager




step:3

# Download and install Xray 26.2.4
cd /tmp
wget https://github.com/XTLS/Xray-core/releases/download/v26.2.4/Xray-linux-64.zip
unzip Xray-linux-64.zip
sudo cp xray /usr/local/bin/
sudo chmod +x /usr/local/bin/xray

# Verify installation
xray version








step 4:
# Create minimal config file
cat > /tmp/config.json << 'EOF'
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

# Copy to config location
sudo cp /tmp/config.json /etc/xray/config.json
sudo cp /tmp/config.json /usr/local/etc/xray/config.json

# Set permissions
sudo chmod 644 /etc/xray/config.json






step5:


# Create the service file
sudo tee /etc/systemd/system/xray.service > /dev/null << 'EOF'
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload and start
sudo systemctl daemon-reload
sudo systemctl enable xray
sudo systemctl start xray

# Check status
sudo systemctl status xray















clone:

sudo git clone https://github.com/razhanamini/v2chain-vps.git /opt/xray-manager


curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 3. Install dependencies and build
npm install
npm run build

# 4. Verify the built file exists
ls -la dist/app.js


# Ensure everything is accessible
sudo chown -R root:root /opt/xray-manager
sudo chmod 755 /opt/xray-manager
sudo chmod 644 /opt/xray-manager/.env  # If .env exists




# Check the service file
cat /etc/systemd/system/xray-manager.service

# If you want to run directly without start.sh, use this instead:
sudo tee /etc/systemd/system/xray-manager.service > /dev/null << 'EOF'
[Unit]
Description=Xray Manager API
After=network.target xray.service
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/xray-manager
ExecStart=/usr/bin/node dist/app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

# Optional: Load .env file
# EnvironmentFile=/opt/xray-manager/.env

[Install]
WantedBy=multi-user.target
EOF








# Reload systemd
sudo systemctl daemon-reload

# Start services
sudo systemctl start xray
sudo systemctl start xray-manager

# Enable to start on boot
sudo systemctl enable xray
sudo systemctl enable xray-manager

# Check status
sudo systemctl status xray-manager
sudo systemctl status xray