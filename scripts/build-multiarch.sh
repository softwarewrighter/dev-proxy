#!/bin/bash
# Build dev-proxy for both arm64 (Mac) and amd64 (Linux/DO)
# Requires Docker buildx

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Build dev-proxy for multiple architectures (arm64 and amd64)."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DO_REGISTRY   Container registry URL (required)"
    echo "  TAG           Image tag (default: latest)"
    echo ""
    echo "Example:"
    echo "  export DO_REGISTRY=registry.digitalocean.com/your-registry"
    echo "  export TAG=v1.0.0"
    echo "  $0"
    echo ""
    echo "Requirements:"
    echo "  - Docker buildx must be installed"
    echo "  - Run 'docker buildx create --use' if not already configured"
    exit 0
fi

# Configuration
if [ -z "$DO_REGISTRY" ]; then
    echo "Error: DO_REGISTRY environment variable not set"
    echo "Example: export DO_REGISTRY=registry.digitalocean.com/your-registry"
    exit 1
fi

REGISTRY="$DO_REGISTRY"
IMAGE_NAME="dev-proxy"
TAG="${TAG:-latest}"
FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$TAG"

echo "Building multi-arch dev-proxy..."
echo "Registry: $REGISTRY"
echo "Image: $IMAGE_NAME:$TAG"
echo ""

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "Error: Docker buildx is not available"
    echo "Install with: docker buildx create --use"
    exit 1
fi

# Create builder if it doesn't exist
if ! docker buildx inspect multiarch-builder &> /dev/null; then
    echo "Creating buildx builder..."
    docker buildx create --name multiarch-builder --use
fi

# Build for both platforms
echo "Building for linux/amd64 and linux/arm64..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "$FULL_IMAGE" \
    .

echo ""
echo "✓ Multi-arch build complete"
echo ""
echo "Registry image: $FULL_IMAGE"
echo ""
echo "Note: Multi-arch builds cannot be loaded to local Docker."
echo "To build for local use, run: ./scripts/build-local.sh"
echo ""
echo "To push to registry, run:"
echo "  ./scripts/push-to-registry.sh"
