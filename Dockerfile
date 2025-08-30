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

# Debug: Show the entire directory structure
RUN echo "=== Full directory structure ===" && \
    find /opt/node_app -type f -name "*.html" && \
    echo "=== All directories ===" && \
    find /opt/node_app -type d -maxdepth 3

# Find and copy build output more reliably
RUN mkdir -p /build-output && \
    if [ -d "/opt/node_app/build" ]; then \
        echo "Found /opt/node_app/build" && cp -r /opt/node_app/build/* /build-output/; \
    elif [ -d "/opt/node_app/dist" ]; then \
        echo "Found /opt/node_app/dist" && cp -r /opt/node_app/dist/* /build-output/; \
    elif [ -d "/opt/node_app/packages/excalidraw/build" ]; then \
        echo "Found /opt/node_app/packages/excalidraw/build" && cp -r /opt/node_app/packages/excalidraw/build/* /build-output/; \
    elif [ -d "/opt/node_app/packages/excalidraw/dist" ]; then \
        echo "Found /opt/node_app/packages/excalidraw/dist" && cp -r /opt/node_app/packages/excalidraw/dist/* /build-output/; \
    else \
        echo "No standard build directory found, searching for index.html..." && \
        BUILD_DIR=$(find /opt/node_app -name "index.html" -type f | head -1 | xargs dirname) && \
        if [ ! -z "$BUILD_DIR" ]; then \
            echo "Found build files in: $BUILD_DIR" && cp -r $BUILD_DIR/* /build-output/; \
        else \
            echo "ERROR: No build output found!" && exit 1; \
        fi \
    fi

# Verify we have files
RUN echo "=== Build output contents ===" && ls -la /build-output/

# Production stage
FROM nginx:alpine

# Remove default nginx files
RUN rm -rf /usr/share/nginx/html/*

# Copy built files
COPY --from=builder /build-output /usr/share/nginx/html

# Verify files were copied
RUN echo "=== Nginx html directory ===" && ls -la /usr/share/nginx/html/

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