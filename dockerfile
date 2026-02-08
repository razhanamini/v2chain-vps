# Dockerfile - Debian based (more stable)
FROM node:18-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    sudo \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Create non-root user for runtime
RUN groupadd -g 1001 nodejs && \
    useradd -m -u 1001 -g nodejs nodejs && \
    mkdir -p /var/lib/xray && \
    chown -R nodejs:nodejs /app /var/lib/xray

# Switch to non-root user
USER nodejs

EXPOSE 5000

CMD ["node", "dist/server.js"]