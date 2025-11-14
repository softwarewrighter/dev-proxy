#!/bin/bash
# Test the dev-proxy build locally

set -e

echo "Testing dev-proxy build..."
echo ""

# Build the image
echo "1. Building image..."
docker build -t dev-proxy:test .

echo ""
echo "2. Starting test container..."
docker run -d \
    --name dev-proxy-test \
    -p 8081:8080 \
    -e APP_BACKEND_HOST=example.com \
    -e APP_BACKEND_PORT=3001 \
    -e APP_FRONTEND_HOST=example.com \
    -e APP_FRONTEND_PORT=3000 \
    dev-proxy:test

# Wait for container to start
sleep 2

echo ""
echo "3. Testing health endpoint..."
if curl -f http://localhost:8081/health > /dev/null 2>&1; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    docker logs dev-proxy-test
    docker rm -f dev-proxy-test
    exit 1
fi

echo ""
echo "4. Checking nginx config..."
docker exec dev-proxy-test cat /etc/nginx/conf.d/default.conf | head -20

echo ""
echo "5. Cleanup..."
docker rm -f dev-proxy-test

echo ""
echo "✓ All tests passed"
echo ""
echo "Image: dev-proxy:test"
