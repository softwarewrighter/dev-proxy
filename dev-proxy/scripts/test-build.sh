#!/bin/bash
# Test the dev-proxy build locally

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Test dev-proxy build by creating a test container and validating it."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Test Steps:"
    echo "  1. Build test image (dev-proxy:test)"
    echo "  2. Start test container on port 8081"
    echo "  3. Verify health endpoint responds"
    echo "  4. Check nginx configuration rendering"
    echo "  5. Cleanup test container"
    echo ""
    echo "Example:"
    echo "  $0"
    exit 0
fi

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
