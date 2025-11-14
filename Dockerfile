# Development Proxy - Simple nginx proxy without SSL
# Multi-arch build for Mac (arm64) and Linux (amd64)

FROM nginx:1.25.3-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy nginx configuration template
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Expose proxy port
EXPOSE 8080

# Note: Master process runs as root (standard for nginx in containers)
# but nginx workers automatically run as the unprivileged 'nginx' user

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Nginx will automatically process templates with envsubst
CMD ["nginx", "-g", "daemon off;"]
