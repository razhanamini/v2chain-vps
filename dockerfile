# Dockerfile - Minimal
FROM node:18-slim

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (curl is already in node:slim)
RUN npm ci --only=production

# Copy source code
COPY . .

EXPOSE 5000

CMD ["node", "dist/server.js"]