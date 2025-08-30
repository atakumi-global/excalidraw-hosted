# Use the official Node.js image as base
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /opt/node_app

# Install git and other dependencies
RUN apk add --no-cache git python3 make g++

# Clone Excalidraw source
RUN git clone https://github.com/excalidraw/excalidraw.git .

# Install dependencies
RUN yarn install --frozen-lockfile --network-timeout 600000

# Set environment variables for build
ENV NODE_ENV=production
ENV REACT_APP_WS_SERVER_URL=wss://whiteboard.atakumi.net
ENV REACT_APP_SOCKET_SERVER_URL=wss://whiteboard.atakumi.net

# Build the application
RUN yarn build

# Production stage
FROM nginx:alpine

# Copy built files (check both possible locations)
COPY --from=builder /opt/node_app/dist /usr/share/nginx/html

# If dist doesn't exist, let's also try build directory as fallback
# COPY --from=builder /opt/node_app/build /usr/share/nginx/html

# Create nginx config
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    \
    location / { \
        root /usr/share/nginx/html; \
        try_files $uri $uri/ /index.html; \
    } \
    \
    location /socket.io/ { \
        proxy_pass http://excalidraw-backend:8080; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]