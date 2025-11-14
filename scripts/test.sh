#!/bin/bash
# Test the dev-proxy with mock backend and frontend services

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Test dev-proxy by creating a complete test environment:"
    echo "  1. Create test Docker network"
    echo "  2. Start mock backend service (internal only)"
    echo "  3. Start mock frontend service (internal only)"
    echo "  4. Start dev-proxy (exposed on localhost:8081)"
    echo "  5. Test all routing:"
    echo "     - Health endpoint: /health"
    echo "     - API routing: /api/* → backend"
    echo "     - Frontend routing: /* → frontend"
    echo "  6. Cleanup all test resources"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0"
    echo ""
    echo "Requirements:"
    echo "  - Port 8081 must be available on your host"
    echo ""
    echo "Note: This test runs completely standalone and doesn't require"
    echo "      any other projects or services to be running."
    echo "      Mock services only run inside Docker network (no host port conflicts)."
    exit 0
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Dev Proxy - Functional Test Suite"
echo "========================================="
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up test resources..."
    docker rm -f dev-proxy-test-backend 2>/dev/null || true
    docker rm -f dev-proxy-test-frontend 2>/dev/null || true
    docker rm -f dev-proxy-test 2>/dev/null || true
    docker network rm dev-proxy-test-network 2>/dev/null || true
    echo "✓ Cleanup complete"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Step 1: Build the image
echo "Step 1/6: Building dev-proxy image..."
echo "-----------------------------------------"
if ! docker build -t dev-proxy:test . -q; then
    echo -e "${RED}✗ Failed to build image${NC}"
    echo ""
    echo "Trying again with verbose output:"
    docker build -t dev-proxy:test .
    exit 1
fi
echo -e "${GREEN}✓ Image built${NC}"
echo ""

# Verify image exists
if ! docker image inspect dev-proxy:test >/dev/null 2>&1; then
    echo -e "${RED}✗ Image dev-proxy:test not found${NC}"
    echo "Available images:"
    docker images | grep dev-proxy || echo "No dev-proxy images found"
    exit 1
fi

# Step 2: Create test network
echo "Step 2/6: Creating test network..."
echo "-----------------------------------------"
docker network create dev-proxy-test-network
echo -e "${GREEN}✓ Network created: dev-proxy-test-network${NC}"
echo ""

# Step 3: Start mock backend service
echo "Step 3/6: Starting mock backend service..."
echo "-----------------------------------------"
docker run -d \
    --name dev-proxy-test-backend \
    --network dev-proxy-test-network \
    --rm \
    nginx:alpine sh -c 'echo "BACKEND_RESPONSE" > /usr/share/nginx/html/index.html && nginx -g "daemon off;"' \
    >/dev/null
sleep 2
echo -e "${GREEN}✓ Mock backend started (dev-proxy-test-backend:80)${NC}"
echo ""

# Step 4: Start mock frontend service
echo "Step 4/6: Starting mock frontend service..."
echo "-----------------------------------------"
docker run -d \
    --name dev-proxy-test-frontend \
    --network dev-proxy-test-network \
    --rm \
    nginx:alpine sh -c 'echo "FRONTEND_RESPONSE" > /usr/share/nginx/html/index.html && nginx -g "daemon off;"' \
    >/dev/null
sleep 2
echo -e "${GREEN}✓ Mock frontend started (dev-proxy-test-frontend:80)${NC}"
echo ""

# Step 5: Start dev-proxy
echo "Step 5/6: Starting dev-proxy..."
echo "-----------------------------------------"

# Check if port 8081 is available
if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${RED}✗ Port 8081 is already in use${NC}"
    echo "Please stop the service using port 8081 and try again:"
    echo "  lsof -i :8081"
    exit 1
fi

# Start the proxy container
echo "Starting container with image: dev-proxy:test"
DOCKER_ERROR=$(docker run -d \
    --name dev-proxy-test \
    --network dev-proxy-test-network \
    -p 8081:8080 \
    --rm \
    -e APP_BACKEND_HOST=dev-proxy-test-backend \
    -e APP_BACKEND_PORT=80 \
    -e APP_FRONTEND_HOST=dev-proxy-test-frontend \
    -e APP_FRONTEND_PORT=80 \
    dev-proxy:test 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to start dev-proxy container${NC}"
    echo ""
    echo "Docker error:"
    echo "$DOCKER_ERROR"
    echo ""
    echo "Diagnostics:"
    echo "  - Image exists: $(docker image inspect dev-proxy:test >/dev/null 2>&1 && echo 'yes' || echo 'NO')"
    echo "  - Network exists: $(docker network inspect dev-proxy-test-network >/dev/null 2>&1 && echo 'yes' || echo 'NO')"
    echo "  - Port 8081 available: $(lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1 && echo 'NO (in use)' || echo 'yes')"
    exit 1
fi

CONTAINER_ID="$DOCKER_ERROR"
echo "Container started: $CONTAINER_ID"

# Wait for proxy to be ready
echo "Waiting for proxy to be ready..."
for i in {1..15}; do
    # Check if container is still running
    if ! docker ps --filter "name=dev-proxy-test" --format "{{.Names}}" | grep -q "dev-proxy-test"; then
        echo -e "${RED}✗ Proxy container exited unexpectedly${NC}"
        echo ""
        echo "Container logs:"
        docker logs dev-proxy-test 2>&1 || echo "No logs available"
        exit 1
    fi

    # Check if health endpoint is responding
    if curl -sf http://localhost:8081/health >/dev/null 2>&1; then
        break
    fi

    if [ $i -eq 15 ]; then
        echo -e "${RED}✗ Proxy failed to become healthy${NC}"
        echo ""
        echo "Container status:"
        docker ps -a --filter "name=dev-proxy-test"
        echo ""
        echo "Container logs:"
        docker logs dev-proxy-test
        exit 1
    fi
    sleep 1
done
echo -e "${GREEN}✓ Dev-proxy started (localhost:8081)${NC}"
echo ""

# Step 6: Run tests
echo "Step 6/6: Running functional tests..."
echo "-----------------------------------------"

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Health endpoint
echo -n "Test 1: Health endpoint (/health)... "
RESPONSE=$(curl -sf http://localhost:8081/health 2>&1)
if [[ "$RESPONSE" == "OK" ]]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Expected: OK"
    echo "  Got: $RESPONSE"
    ((TESTS_FAILED++))
fi

# Test 2: API routing to backend
echo -n "Test 2: API routing (/api/* → backend)... "
RESPONSE=$(curl -sf http://localhost:8081/api/ 2>&1)
if [[ "$RESPONSE" == "BACKEND_RESPONSE" ]]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Expected: BACKEND_RESPONSE"
    echo "  Got: $RESPONSE"
    ((TESTS_FAILED++))
fi

# Test 3: Frontend routing
echo -n "Test 3: Frontend routing (/* → frontend)... "
RESPONSE=$(curl -sf http://localhost:8081/ 2>&1)
if [[ "$RESPONSE" == "FRONTEND_RESPONSE" ]]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Expected: FRONTEND_RESPONSE"
    echo "  Got: $RESPONSE"
    ((TESTS_FAILED++))
fi

# Test 4: Security headers
echo -n "Test 4: Security headers present... "
HEADERS=$(curl -sI http://localhost:8081/ 2>&1)
if echo "$HEADERS" | grep -q "X-Frame-Options" && \
   echo "$HEADERS" | grep -q "X-Content-Type-Options" && \
   echo "$HEADERS" | grep -q "X-XSS-Protection"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Missing expected security headers"
    ((TESTS_FAILED++))
fi

# Test 5: Configuration rendering
echo -n "Test 5: Environment variable substitution... "
CONFIG=$(docker exec dev-proxy-test cat /etc/nginx/conf.d/default.conf 2>&1)
if echo "$CONFIG" | grep -q "dev-proxy-test-backend:80" && \
   echo "$CONFIG" | grep -q "dev-proxy-test-frontend:80"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Environment variables not properly substituted"
    ((TESTS_FAILED++))
fi

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo ""
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC} ($TESTS_PASSED/$((TESTS_PASSED + TESTS_FAILED)))"
    echo ""
    echo "Test environment details:"
    echo "  - Network: dev-proxy-test-network (isolated Docker network)"
    echo "  - Backend: dev-proxy-test-backend:80 (internal, returns 'BACKEND_RESPONSE')"
    echo "  - Frontend: dev-proxy-test-frontend:80 (internal, returns 'FRONTEND_RESPONSE')"
    echo "  - Proxy: http://localhost:8081 (exposed to host)"
    echo ""
    echo "All services communicate through the proxy - no direct host access to backend/frontend."
    echo ""
    echo "You can test manually via the proxy:"
    echo "  curl http://localhost:8081/health    # Should return 'OK'"
    echo "  curl http://localhost:8081/api/      # Should return 'BACKEND_RESPONSE'"
    echo "  curl http://localhost:8081/          # Should return 'FRONTEND_RESPONSE'"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC} (Passed: $TESTS_PASSED, Failed: $TESTS_FAILED)"
    echo ""
    echo "Showing dev-proxy logs:"
    docker logs dev-proxy-test
    echo ""
    exit 1
fi
