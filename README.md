# Dev Proxy

A simple nginx-based development proxy for testing containerized applications locally without SSL. This proxy allows you to access your app's frontend and backend through a single localhost port.

**📖 New to this project? See [QUICK_START.md](QUICK_START.md) for common tasks like building, testing, and pushing to registries.**

## Features

- **No SSL** - Simple HTTP proxy for local development
- **Multi-arch** - Builds for both Mac (arm64) and Linux (amd64)
- **Configurable** - Point to any app's docker network and services
- **Lightweight** - Based on nginx:alpine
- **Health checks** - Built-in health monitoring

## Architecture

```
localhost:8080 (dev-proxy)
├── /api/*    → app-backend:3001
└── /*        → app-frontend:3000
```

## Quick Start

### 1. Configure for your app

Copy the example environment file:
```bash
cp .env.example .env
```

Edit `.env` to match your app's configuration:
```bash
# For crudibase
APP_NETWORK=crudibase-network
APP_BACKEND_HOST=crudibase-backend
APP_FRONTEND_HOST=crudibase-frontend

# For cruditrack
APP_NETWORK=cruditrack-network
APP_BACKEND_HOST=cruditrack-backend
APP_FRONTEND_HOST=cruditrack-frontend
```

### 2. Start your app

Make sure your app is running first:
```bash
cd /path/to/your/app
docker compose up -d
```

### 3. Start the dev proxy

```bash
docker compose up -d
```

### 4. Access your app

Open your browser to:
```
http://localhost:8080
```

## Building and Testing

### Build for Local Development

Build for your current platform (Mac or Linux):

```bash
./scripts/build-local.sh
```

This creates `dev-proxy:latest` for immediate use.

### Build for All Platforms

Build for both Mac (arm64) and Linux (amd64):

```bash
# Local only (no registry needed)
./scripts/build-all.sh --local-only

# Build all + push to registry
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=your-token-here
./scripts/build-all.sh
```

The `build-all.sh` script will:
1. Build for your local platform (immediate use)
2. Build multi-arch image (arm64 + amd64)
3. Push to registry (if credentials provided)

### Test the Proxy

Run comprehensive tests without any external dependencies:

```bash
./scripts/test.sh
```

This will:
- Create mock backend and frontend services
- Start the dev-proxy
- Test all routing (health, API, frontend)
- Verify security headers
- Automatically cleanup

### Individual Build Scripts

```bash
# Local build only
./scripts/build-local.sh

# Multi-arch build (requires DO_REGISTRY)
export DO_REGISTRY=registry.digitalocean.com/your-registry
./scripts/build-multiarch.sh

# Push to registry (requires DO_REGISTRY and DO_TOKEN)
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=your-token-here
./scripts/push-to-registry.sh
```

All scripts support `--help` for detailed usage information.

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `PROXY_PORT` | 8080 | External port to access the proxy |
| `APP_NETWORK` | app-network | Docker network name of your app |
| `APP_BACKEND_HOST` | app-backend | Container name of backend service |
| `APP_BACKEND_PORT` | 3001 | Port of backend service |
| `APP_FRONTEND_HOST` | app-frontend | Container name of frontend service |
| `APP_FRONTEND_PORT` | 3000 | Port of frontend service |

## Standardized Ports

All apps should use these standardized internal ports:
- **Frontend**: 3000
- **Backend**: 3001

This allows the dev-proxy to work with any app using the same configuration pattern.

## Troubleshooting

### Can't connect to app

Make sure:
1. Your app is running: `docker compose ps`
2. The proxy is on the same network: Check `APP_NETWORK` in `.env`
3. Container names match: `docker ps` should show containers with names matching your config

### Health check failing

Check proxy logs:
```bash
docker compose logs dev-proxy
```

### Connection refused

Verify your app's backend/frontend are listening on the correct ports:
```bash
docker compose exec backend wget -O- http://localhost:3001/health
docker compose exec frontend wget -O- http://localhost:3000/
```

## License

MIT
