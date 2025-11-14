#!/bin/bash
# Push dev-proxy to Digital Ocean Container Registry

set -e

# Configuration
REGISTRY="${DO_REGISTRY:-registry.digitalocean.com/crudibase-registry}"
IMAGE_NAME="dev-proxy"
TAG="${TAG:-latest}"
FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$TAG"

echo "Pushing dev-proxy to registry..."
echo "Registry: $REGISTRY"
echo "Image: $IMAGE_NAME:$TAG"
echo ""

# Check if image exists locally
if ! docker image inspect "$FULL_IMAGE" &> /dev/null; then
    echo "Error: Image $FULL_IMAGE not found locally"
    echo "Build it first with: ./scripts/build-multiarch.sh"
    exit 1
fi

# Check if logged into registry
if ! docker info | grep -q "$REGISTRY"; then
    echo "Logging into Digital Ocean registry..."
    if [ -z "$DO_TOKEN" ]; then
        echo "Error: DO_TOKEN environment variable not set"
        echo "Set it with: export DO_TOKEN=your-token"
        exit 1
    fi
    echo "$DO_TOKEN" | docker login "$REGISTRY" -u "$DO_TOKEN" --password-stdin
fi

# Push the image
echo "Pushing multi-arch image..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "$FULL_IMAGE" \
    --push \
    .

echo ""
echo "✓ Push complete"
echo ""
echo "Image available at: $FULL_IMAGE"
echo ""
echo "Pull on any platform with:"
echo "  docker pull $FULL_IMAGE"
