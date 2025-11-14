#!/bin/bash
# Build dev-proxy for local platform

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Build dev-proxy for the current platform only."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0"
    echo ""
    echo "Output:"
    echo "  Creates: dev-proxy:latest (for current platform)"
    exit 0
fi

echo "Building dev-proxy for local platform..."

docker build -t dev-proxy:latest .

echo "✓ Build complete"
echo ""
echo "Image: dev-proxy:latest"
echo "Platform: $(uname -m)"
