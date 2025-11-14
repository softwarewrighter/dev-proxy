#!/bin/bash
# Build dev-proxy for local platform

set -e

echo "Building dev-proxy for local platform..."

docker build -t dev-proxy:latest .

echo "✓ Build complete"
echo ""
echo "Image: dev-proxy:latest"
echo "Platform: $(uname -m)"
