#!/bin/bash
# Test the dev-proxy with mock backend and frontend services

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Test dev-proxy by creating a complete test environment:"
    echo "  1. Create test Docker network"
    echo "  2. Start mock backend service (port 3001)"
    echo "  3. Start mock frontend service (port 3000)"
    echo "  4. Start dev-proxy (port 8081)"
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
    echo "Note: This test runs completely standalone and doesn't require"
    echo "      any other projects or services to be running."
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
docker build -t dev-proxy:test . -q
echo -e "${GREEN}✓ Image built${NC}"
echo ""

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
    -p 3001:80 \
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
    -p 3000:80 \
    --rm \
    nginx:alpine sh -c 'echo "FRONTEND_RESPONSE" > /usr/share/nginx/html/index.html && nginx -g "daemon off;"' \
    >/dev/null
sleep 2
echo -e "${GREEN}✓ Mock frontend started (dev-proxy-test-frontend:80)${NC}"
echo ""

# Step 5: Start dev-proxy
echo "Step 5/6: Starting dev-proxy..."
echo "-----------------------------------------"
docker run -d \
    --name dev-proxy-test \
    --network dev-proxy-test-network \
    -p 8081:8080 \
    --rm \
    -e APP_BACKEND_HOST=dev-proxy-test-backend \
    -e APP_BACKEND_PORT=80 \
    -e APP_FRONTEND_HOST=dev-proxy-test-frontend \
    -e APP_FRONTEND_PORT=80 \
    dev-proxy:test \
    >/dev/null

# Wait for proxy to be ready
echo "Waiting for proxy to be ready..."
for i in {1..10}; do
    if curl -sf http://localhost:8081/health >/dev/null 2>&1; then
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}✗ Proxy failed to start${NC}"
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
    echo "  - Network: dev-proxy-test-network"
    echo "  - Backend: http://localhost:3001 (nginx, returns 'BACKEND_RESPONSE')"
    echo "  - Frontend: http://localhost:3000 (nginx, returns 'FRONTEND_RESPONSE')"
    echo "  - Proxy: http://localhost:8081"
    echo ""
    echo "You can test manually before cleanup:"
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
