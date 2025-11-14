#!/bin/bash
# Push dev-proxy to Digital Ocean Container Registry

set -e

# Show help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Push multi-arch dev-proxy image to container registry."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DO_REGISTRY   Container registry URL (required)"
    echo "  DO_TOKEN      Registry authentication token (required)"
    echo "  TAG           Image tag (default: latest)"
    echo ""
    echo "Example:"
    echo "  export DO_REGISTRY=registry.digitalocean.com/your-registry"
    echo "  export DO_TOKEN=your-token-here"
    echo "  export TAG=v1.0.0"
    echo "  $0"
    echo ""
    echo "Note:"
    echo "  - Run build-multiarch.sh before pushing"
    echo "  - Requires Docker buildx"
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
