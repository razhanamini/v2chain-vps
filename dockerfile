# Dockerfile
FROM node:18-slim

# Set DNS resolver and npm registry

RUN npm config set registry https://registry.npmmirror.com/ && \
    npm config set strict-ssl false
    

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with retry
RUN npm ci --only=production --progress=true --loglevel=info || \
    (echo "First attempt failed, retrying..." && npm ci --only=production)

# Copy source code
COPY . .

RUN npm run build

EXPOSE 5000

CMD ["node", "dist/app.js"]