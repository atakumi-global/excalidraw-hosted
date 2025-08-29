# Use the official Node.js image as base
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /opt/node_app

# Clone Excalidraw source
RUN apk add --no-cache git
RUN git clone https://github.com/excalidraw/excalidraw.git .

# Install dependencies
RUN yarn install --frozen-lockfile --network-timeout 600000

# Build with custom environment variables
ENV REACT_APP_WS_SERVER_URL=wss://excalidraw.atakumi.net
ENV REACT_APP_SOCKET_SERVER_URL=wss://excalidraw.atakumi.net

RUN yarn build:app

# Production stage
FROM nginx:alpine
COPY --from=builder /opt/node_app/build /usr/share/nginx/html

# Custom nginx config for WebSocket support
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