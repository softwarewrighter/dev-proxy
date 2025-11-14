#!/bin/bash
# Build dev-proxy for both arm64 (Mac) and amd64 (Linux/DO)
# Requires Docker buildx

set -e

# Configuration
REGISTRY="${DO_REGISTRY:-registry.digitalocean.com/crudibase-registry}"
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
    -t dev-proxy:latest \
    -t "$FULL_IMAGE" \
    --load \
    .

echo ""
echo "✓ Multi-arch build complete"
echo ""
echo "Local image: dev-proxy:latest"
echo "Registry image: $FULL_IMAGE"
echo ""
echo "To push to registry, run:"
echo "  ./scripts/push-to-registry.sh"
