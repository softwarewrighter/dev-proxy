# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Security Considerations

### Intended Use

**IMPORTANT:** This proxy is designed exclusively for **local development testing** and should **NEVER** be used in production environments or exposed to the public internet.

### Known Limitations

1. **No SSL/TLS Support**
   - This proxy operates over HTTP only (no HTTPS)
   - All traffic is unencrypted
   - Intended only for `localhost` access
   - **Never expose this service to external networks**

2. **Development Context Only**
   - No authentication/authorization mechanisms
   - No rate limiting (except request body size)
   - No WAF or DDoS protection
   - Minimal security hardening

3. **Network Isolation**
   - Ensure the Docker network is isolated from untrusted networks
   - Run only on localhost or trusted development networks
   - Do not bridge to public network interfaces

### Security Features

Despite being a development tool, we implement security best practices where appropriate:

- ✅ **Non-root execution**: Container runs as `nginx` user (not root)
- ✅ **Minimal base image**: Alpine Linux reduces attack surface
- ✅ **Health checks**: Prevents unhealthy containers from serving traffic
- ✅ **Security headers**: X-Frame-Options, X-Content-Type-Options, etc.
- ✅ **Request size limits**: 20MB max body size prevents large upload attacks
- ✅ **Explicit permissions**: Only necessary directories are writable
- ✅ **Pinned dependencies**: Base image version is locked
- ✅ **Timeout configurations**: Prevents hanging connections

### Threat Model

**In Scope:**
- Container escape vulnerabilities
- Dependency vulnerabilities (nginx, Alpine packages)
- Configuration errors leading to unintended exposure
- Secrets leakage via logs or environment variables

**Out of Scope:**
- Network-level attacks (DDoS, etc.) - development tool only
- SSL/TLS vulnerabilities - HTTP-only by design
- Authentication bypass - no auth by design
- Data encryption in transit - local development only

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

### How to Report

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. Email the maintainers directly with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### What to Expect

- **Initial Response**: Within 48 hours
- **Status Update**: Within 1 week
- **Resolution Timeline**: Varies by severity
  - Critical: Within 1 week
  - High: Within 2 weeks
  - Medium: Within 1 month
  - Low: Next release cycle

### Disclosure Policy

- We follow coordinated vulnerability disclosure
- Security fixes will be released as soon as possible
- Credit will be given to reporters (unless anonymity is requested)
- CVEs will be requested for significant vulnerabilities

## Security Best Practices for Users

### Environment Variables

1. **Never commit `.env` files** to version control (already in `.gitignore`)
2. **Rotate registry tokens** regularly if pushing to container registries
3. **Use environment-specific configs** - separate dev/staging/prod

### Docker Security

1. **Keep Docker updated** to the latest stable version
2. **Scan images regularly**: `docker scan dev-proxy:latest`
3. **Review container logs** for suspicious activity
4. **Limit resource usage** with Docker constraints if needed

### Network Security

1. **Isolate Docker networks** - use dedicated networks per app
2. **Never bind to 0.0.0.0** unless necessary
3. **Use firewall rules** to restrict access to localhost only
4. **Monitor network traffic** during development

### Dependency Management

1. **Keep base image updated**: Rebuild regularly for security patches
2. **Review Alpine security advisories**: https://alpinelinux.org/
3. **Monitor nginx security releases**: https://nginx.org/en/security_advisories.html

## Security Updates

Security updates will be documented in [CHANGELOG.md](CHANGELOG.md) under the "Security" section.

## Acknowledgments

We appreciate the security research community and will acknowledge reporters of valid security issues (with permission).

---

**Last Updated:** 2025-01-14
