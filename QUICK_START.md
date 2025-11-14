# Quick Reference Guide

## Building Images

### 1. Build for Local Use (Fastest)
```bash
./scripts/build-local.sh
```
Creates: `dev-proxy:latest` for your current platform (Mac or Linux)

### 2. Build Everything
```bash
# Local only
./scripts/build-all.sh --local-only

# Build + push to registry
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=your-token-here
./scripts/build-all.sh
```

## Pushing to Registry

### Step-by-step: Push to Digital Ocean Container Registry

**1. Set environment variables:**
```bash
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=dop_v1_abc123...
export TAG=latest  # optional, defaults to 'latest'
```

**2. Build multi-arch image:**
```bash
./scripts/build-multiarch.sh
```
This builds for both arm64 (Mac) and amd64 (Linux).

**3. Push to registry:**
```bash
./scripts/push-to-registry.sh
```

### All-in-One Command

```bash
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=dop_v1_abc123...
./scripts/build-all.sh
```

This will:
1. Build for local platform
2. Build multi-arch (arm64 + amd64)
3. Push to registry

## Testing

### Run All Tests
```bash
./scripts/test.sh
```

Tests:
- Health endpoint
- API routing (/api/* → backend)
- Frontend routing (/* → frontend)
- Security headers
- Environment variable substitution

Requires: Port 8081 available on host

## Getting Your Registry Token

### Digital Ocean
1. Go to https://cloud.digitalocean.com/account/api/tokens
2. Generate New Token
3. Select "Read" and "Write" scopes
4. Copy the token (starts with `dop_v1_`)

```bash
export DO_TOKEN=dop_v1_your_token_here
```

### Using with Other Registries

The scripts work with any Docker registry. Just change the `DO_REGISTRY` variable:

```bash
# Docker Hub
export DO_REGISTRY=docker.io/yourusername
export DO_TOKEN=your_docker_hub_token

# AWS ECR
export DO_REGISTRY=123456789.dkr.ecr.us-east-1.amazonaws.com
# For ECR, get token with: aws ecr get-login-password

# GitHub Container Registry
export DO_REGISTRY=ghcr.io/yourusername
export DO_TOKEN=ghp_your_github_token
```

## Common Issues

### "Port already allocated"
Another container is using the port. Stop it:
```bash
docker ps | grep :8081
docker stop <container-name>
```

### "Failed to build image"
Check Dockerfile syntax:
```bash
docker build -t dev-proxy:test .
```

### "Failed to push"
Check registry authentication:
```bash
echo $DO_TOKEN | docker login $DO_REGISTRY -u $DO_TOKEN --password-stdin
```

### "Image not found"
Build the image first:
```bash
./scripts/build-local.sh
```

## Help

All scripts support `--help`:
```bash
./scripts/build-all.sh --help
./scripts/build-local.sh --help
./scripts/build-multiarch.sh --help
./scripts/push-to-registry.sh --help
./scripts/test.sh --help
```
