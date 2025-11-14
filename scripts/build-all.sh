#!/bin/bash
# Build dev-proxy for all platforms (local + multi-arch)

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build dev-proxy for all platforms:"
    echo "  1. Local platform (for immediate use)"
    echo "  2. Multi-arch (arm64 + amd64 for registry)"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  --local-only     Build only for local platform"
    echo "  --skip-push      Build multi-arch but don't push to registry"
    echo ""
    echo "Environment Variables:"
    echo "  DO_REGISTRY      Container registry URL (required for multi-arch)"
    echo "  DO_TOKEN         Registry authentication token (required for push)"
    echo "  TAG              Image tag (default: latest)"
    echo ""
    echo "Example - Local only:"
    echo "  $0 --local-only"
    echo ""
    echo "Example - Build all (requires registry):"
    echo "  export DO_REGISTRY=registry.digitalocean.com/your-registry"
    echo "  export DO_TOKEN=your-token-here"
    echo "  $0"
    echo ""
    echo "Example - Build but don't push:"
    echo "  export DO_REGISTRY=registry.digitalocean.com/your-registry"
    echo "  $0 --skip-push"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ONLY=false
SKIP_PUSH=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --skip-push)
            SKIP_PUSH=true
            shift
            ;;
    esac
done

echo "========================================="
echo "Dev Proxy - Build All Platforms"
echo "========================================="
echo ""

# Step 1: Build for local platform
echo "Step 1/3: Building for local platform..."
echo "-----------------------------------------"
"$SCRIPT_DIR/build-local.sh"
echo ""

if [ "$LOCAL_ONLY" = true ]; then
    echo "========================================="
    echo "✓ Build complete (local only)"
    echo "========================================="
    echo ""
    echo "Local image available: dev-proxy:latest"
    echo ""
    echo "To test: ./scripts/test.sh"
    exit 0
fi

# Step 2: Build multi-arch
echo "Step 2/3: Building multi-arch (arm64 + amd64)..."
echo "-----------------------------------------"
if [ -z "$DO_REGISTRY" ]; then
    echo "⚠ Skipping multi-arch build (DO_REGISTRY not set)"
    echo ""
    echo "To build for multiple architectures, set:"
    echo "  export DO_REGISTRY=registry.digitalocean.com/your-registry"
else
    "$SCRIPT_DIR/build-multiarch.sh"
    echo ""

    # Step 3: Push to registry
    if [ "$SKIP_PUSH" = true ]; then
        echo "Step 3/3: Skipping registry push (--skip-push)"
        echo "-----------------------------------------"
        echo "⚠ Multi-arch image built but not pushed"
    else
        echo "Step 3/3: Pushing to registry..."
        echo "-----------------------------------------"
        "$SCRIPT_DIR/push-to-registry.sh"
    fi
fi

echo ""
echo "========================================="
echo "✓ All builds complete!"
echo "========================================="
echo ""
echo "Available images:"
echo "  - Local: dev-proxy:latest"
if [ -n "$DO_REGISTRY" ]; then
    echo "  - Registry: $DO_REGISTRY/dev-proxy:${TAG:-latest}"
fi
echo ""
echo "To test: ./scripts/test.sh"
