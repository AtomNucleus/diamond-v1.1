# Use a lightweight Node.js image
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Install dependencies first
COPY diamond-backend/package*.json ./
RUN npm ci --omit=dev

# Bundle app source
COPY diamond-backend/ ./

# Render provides PORT; the app must listen on it
ENV NODE_ENV=production

# Optionally document the port
EXPOSE 8080

# Start the server
CMD ["node", "index.js"]
