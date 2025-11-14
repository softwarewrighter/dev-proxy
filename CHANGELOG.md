# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- MIT LICENSE file
- CHANGELOG.md for version tracking
- SECURITY.md with security policies
- .dockerignore for cleaner builds
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Timeout configurations for proxy connections
- --help flag support for all scripts
- Executable permissions for scripts

### Changed
- Pinned nginx base image to specific version (1.25.3-alpine)
- Removed hardcoded registry values from scripts
- Fixed --load flag incompatibility in build-multiarch.sh

### Security
- Added security response headers to nginx configuration
- Pinned base image version to prevent automatic updates
- Added proxy timeout configurations to prevent hanging connections

## [0.1.0] - 2025-01-14

### Added
- Initial release
- Nginx-based reverse proxy for local development
- Multi-architecture build support (arm64, amd64)
- Docker Compose orchestration
- Environment-based configuration
- Health check endpoint
- Build scripts (local, multiarch, test, push)
- Comprehensive README documentation
- Example environment configuration

### Features
- HTTP reverse proxy (no SSL)
- /api/* routing to backend service
- /* routing to frontend service
- WebSocket support via Upgrade headers
- Gzip compression
- 20MB request body limit
- Health monitoring with Docker healthchecks
- Non-root container execution

[Unreleased]: https://github.com/your-org/dev-proxy/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/dev-proxy/releases/tag/v0.1.0
