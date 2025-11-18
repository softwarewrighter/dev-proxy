# Security

This page documents security considerations, best practices, and the security architecture of Dev Proxy.

## Table of Contents

- [Security Overview](#security-overview)
- [Threat Model](#threat-model)
- [Security Features](#security-features)
- [Container Security](#container-security)
- [Network Security](#network-security)
- [Security Headers](#security-headers)
- [Best Practices](#best-practices)
- [Security Checklist](#security-checklist)

## Security Overview

### Important Notice

**Dev Proxy is designed EXCLUSIVELY for local development and testing. It should NEVER be used in production or exposed to the public internet.**

```mermaid
graph TB
    subgraph "✅ SAFE: Local Development"
        Dev[Developer Laptop] -->|localhost:8080| Proxy1[Dev Proxy]
        Proxy1 --> App1[Local App]
    end

    subgraph "⚠️ UNSAFE: Production Use"
        Internet[Public Internet] -.->|NEVER!| Proxy2[Dev Proxy]
        Proxy2 -.-> App2[Production App]
    end

    style Proxy1 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style Proxy2 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
```

### Why Not Production?

| Feature | Dev Proxy | Production Proxy |
|---------|-----------|------------------|
| SSL/TLS | ❌ HTTP Only | ✅ HTTPS Required |
| Authentication | ❌ None | ✅ Required |
| Rate Limiting | ❌ Basic | ✅ Advanced |
| WAF | ❌ None | ✅ Required |
| DDoS Protection | ❌ None | ✅ Required |
| Logging | ⚠️ Minimal | ✅ Comprehensive |
| Monitoring | ⚠️ Basic | ✅ Advanced |

## Threat Model

### In Scope

Security issues we protect against even in development:

```mermaid
graph TB
    Threats[Security Threats] --> T1[Container Escape]
    Threats --> T2[Dependency Vulnerabilities]
    Threats --> T3[Configuration Errors]
    Threats --> T4[Secrets Leakage]

    T1 --> M1[Non-root workers Minimal permissions]
    T2 --> M2[Pinned versions Regular updates]
    T3 --> M3[Validation Documentation]
    T4 --> M4[.gitignore Documentation]

    style M1 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style M2 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style M3 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style M4 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### Out of Scope

These are NOT threats for a local development tool:

- **Network attacks** (DDoS, etc.) - localhost only
- **SSL/TLS vulnerabilities** - HTTP by design
- **Authentication bypass** - no auth by design
- **Data encryption in transit** - local development only

### Attack Surface

```mermaid
graph TB
    subgraph "External Attack Surface"
        Port[Port 8080 Localhost Only]
    end

    subgraph "Container Attack Surface"
        Nginx[Nginx Process]
        Config[Configuration Files]
        Deps[Dependencies]
    end

    subgraph "Network Attack Surface"
        Docker[Docker Network]
        Services[App Services]
    end

    Port --> Nginx
    Nginx --> Config
    Nginx --> Deps
    Nginx --> Docker
    Docker --> Services

    style Port fill:#ffa94d,stroke:#333,stroke-width:2px
    style Nginx fill:#ffa94d,stroke:#333,stroke-width:2px
```

## Security Features

Despite being a development tool, Dev Proxy implements security best practices:

### Defense in Depth

```mermaid
graph TB
    Request[HTTP Request] --> Layer1[Security Headers]
    Layer1 --> Layer2[Request Size Limits]
    Layer2 --> Layer3[Timeout Protection]
    Layer3 --> Layer4[Non-root Worker]
    Layer4 --> Layer5[Minimal Container]
    Layer5 --> Layer6[Network Isolation]
    Layer6 --> App[Application]

    style Layer1 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Layer2 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Layer3 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Layer4 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Layer5 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Layer6 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

### Security Features Summary

| Feature | Implementation | Purpose |
|---------|----------------|---------|
| **Non-root execution** | nginx user | Limit container escape impact |
| **Minimal base image** | Alpine Linux | Reduce attack surface |
| **Security headers** | X-Frame-Options, etc. | Browser protection |
| **Request limits** | 20MB max body | Prevent large uploads |
| **Timeouts** | 60s default | Prevent hanging connections |
| **Health checks** | Docker healthcheck | Detect compromised containers |
| **Pinned versions** | nginx:1.25.3-alpine | Prevent supply chain attacks |

## Container Security

### Process Isolation

```mermaid
graph TB
    subgraph "Host Machine"
        Docker[Docker Engine root]
    end

    subgraph "dev-proxy Container"
        Master[Nginx Master root PID 1]
        Worker1[Nginx Worker 1 nginx user UID 101]
        Worker2[Nginx Worker 2 nginx user UID 101]

        Master -->|spawn| Worker1
        Master -->|spawn| Worker2
    end

    Docker -->|creates| Master

    style Master fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Worker1 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style Worker2 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Key Points:**

- **Master Process**: Runs as root (standard for nginx)
  - Only manages worker processes
  - Does not handle requests
  - Minimal attack surface

- **Worker Processes**: Run as `nginx` user (UID 101)
  - Handle all HTTP requests
  - Limited privileges
  - Cannot write to most directories

### File System Permissions

```mermaid
graph TB
    subgraph "Read-Only"
        Conf[/etc/nginx/ Configuration]
        Bin[/usr/sbin/nginx Binary]
    end

    subgraph "Writable (nginx user)"
        Logs[/var/log/nginx/ Logs]
        Cache[/var/cache/nginx/ Cache]
        Run[/var/run/ PID files]
    end

    Worker[Nginx Worker nginx user] --> Conf
    Worker --> Bin
    Worker --> Logs
    Worker --> Cache
    Worker --> Run

    style Conf fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Bin fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Logs fill:#ffa94d,stroke:#333,stroke-width:2px
    style Cache fill:#ffa94d,stroke:#333,stroke-width:2px
    style Run fill:#ffa94d,stroke:#333,stroke-width:2px
```

### Container Capabilities

Default Docker capabilities with no additional privileges:

```bash
# View container capabilities
docker inspect dev-proxy --format='{{.HostConfig.CapDrop}}'
docker inspect dev-proxy --format='{{.HostConfig.CapAdd}}'
```

**No privileged mode** - Container runs with minimal capabilities.

### Image Layers Security

```mermaid
graph TB
    Base[nginx:1.25.3-alpine Official Base] --> Verify1[✓ Verified Publisher]

    Base --> Layer1[+ curl package apk add --no-cache]
    Layer1 --> Verify2[✓ Alpine Package Manager Signed packages]

    Layer1 --> Layer2[+ nginx.conf.template COPY]
    Layer2 --> Verify3[✓ Version Controlled Code review]

    Layer2 --> Final[dev-proxy:latest]

    style Verify1 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style Verify2 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style Verify3 fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Security Practices:**

1. **Base Image**: Official nginx image from Docker Hub
2. **Pinned Version**: `nginx:1.25.3-alpine` (not `latest`)
3. **Minimal Additions**: Only `curl` for health checks
4. **No Build Args**: No secrets in build process

## Network Security

### Network Isolation

```mermaid
graph TB
    subgraph "Host Network"
        Host[Host: 0.0.0.0:8080]
    end

    subgraph "Bridge Network"
        Docker[Docker Bridge]
    end

    subgraph "App Network (Isolated)"
        Proxy[dev-proxy 172.20.0.4]
        Backend[app-backend 172.20.0.2]
        Frontend[app-frontend 172.20.0.3]
        DB[(database 172.20.0.5)]
    end

    Host -->|Port mapping| Docker
    Docker -->|NAT| Proxy

    Proxy -.->|Internal| Backend
    Proxy -.->|Internal| Frontend
    Backend -.->|Internal| DB

    Internet[Internet] -.->|Blocked by default| Host

    style Proxy fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

**Network Security Features:**

1. **Isolated Network**: App network separate from host
2. **Port Mapping**: Only proxy port exposed to host
3. **Internal DNS**: Services communicate via names, not IPs
4. **No Public Access**: Firewall blocks external access (default)

### Port Exposure

```mermaid
graph LR
    External[External Requests] -->|❌ Blocked| Firewall[Host Firewall]

    Localhost[Localhost Requests] -->|✅ Allowed| Port[0.0.0.0:8080]

    Port --> Container[Container :8080]

    Container --> Internal1[backend:3001 Not Exposed]
    Container --> Internal2[frontend:3000 Not Exposed]

    style External fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Localhost fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Best Practice**: Only bind to localhost in production environments:

```yaml
ports:
  - "127.0.0.1:8080:8080"  # Localhost only
  # NOT "0.0.0.0:8080:8080"  # All interfaces
```

## Security Headers

### Implemented Headers

Dev Proxy adds security headers to all responses:

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### Header Flow

```mermaid
sequenceDiagram
    participant Browser
    participant Proxy as Dev Proxy
    participant App as Application

    Browser->>Proxy: GET /page

    Proxy->>App: GET /page
    App-->>Proxy: 200 OK
    Note over App,Proxy: Content-Type: text/html

    Note over Proxy: Add security headers

    Proxy-->>Browser: 200 OK
    Note over Proxy,Browser: X-Frame-Options: SAMEORIGIN X-Content-Type-Options: nosniff X-XSS-Protection: 1; mode=block Referrer-Policy: strict-origin-when-cross-origin

    Note over Browser: Apply security policies
```

### Header Explanations

#### X-Frame-Options: SAMEORIGIN

**Purpose**: Prevent clickjacking attacks

```mermaid
graph TB
    Attack[Malicious Site] -.->|Try to embed| Frame[iframe]
    Frame -.->|Blocked by header| YourApp[Your App]

    LegitSite[Your Site] -->|Allowed| Frame2[iframe]
    Frame2 --> YourApp2[Your App]

    style Attack fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style LegitSite fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Effect**: Your app can only be embedded in frames from the same origin.

#### X-Content-Type-Options: nosniff

**Purpose**: Prevent MIME type sniffing

```mermaid
graph LR
    File[File: script.txt Content-Type: text/plain]

    File --> Browser{Browser}

    Browser -.->|Without header| Sniff[MIME Sniff Execute as JavaScript!]
    Browser -->|With header| Respect[Respect Content-Type Treat as text]

    style Sniff fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Respect fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Effect**: Browser respects declared Content-Type, won't guess.

#### X-XSS-Protection: 1; mode=block

**Purpose**: Enable browser's XSS filter

```mermaid
graph TB
    Input[User Input: &lt;script&gt;alert('XSS')&lt;/script&gt;] --> App[Application]

    App --> Response[Response includes unsanitized input]

    Response --> Browser{Browser XSS Filter}

    Browser -->|Header enabled| Block[Block rendering Show error page]
    Browser -.->|Header disabled| Execute[Execute script XSS attack!]

    style Block fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style Execute fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
```

**Effect**: Browser blocks detected XSS attempts.

**Note**: Modern browsers use Content Security Policy instead, but this provides backward compatibility.

#### Referrer-Policy: strict-origin-when-cross-origin

**Purpose**: Control referrer information sent to other sites

```mermaid
graph TB
    YourApp[Your App https://localhost:8080/sensitive/page] --> Click[User clicks link]

    Click --> SameOrigin{Same Origin?}

    SameOrigin -->|Yes| SendFull[Send Full URL https://localhost:8080/sensitive/page]
    SameOrigin -->|No| SendOrigin[Send Origin Only https://localhost:8080]

    style SendFull fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style SendOrigin fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Effect**: External sites only see your origin, not full URLs with sensitive info.

## Best Practices

### Development Environment

#### 1. Secrets Management

```mermaid
graph TB
    Secrets[Secrets & Credentials] --> Git{Store in Git?}

    Git -->|❌ NEVER| Committed[Committed to repo]
    Git -->|✅ YES| Ignored[.gitignore]

    Ignored --> Env[.env file]
    Env --> Local[Local development only]

    Committed --> Exposed[Exposed in history SECURITY BREACH]

    style Committed fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Ignored fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

**Never commit:**
- `.env` files (already in `.gitignore`)
- Registry tokens
- API keys
- Passwords

**Use instead:**
- `.env.example` (template without secrets)
- Environment variables
- Secret management tools (for production)

#### 2. Network Binding

```bash
# ✅ GOOD: Localhost only
ports:
  - "127.0.0.1:8080:8080"

# ⚠️ ACCEPTABLE: All interfaces (for local network testing)
ports:
  - "0.0.0.0:8080:8080"
# But ensure firewall blocks external access!

# ❌ BAD: Never expose to internet
# No public IP binding
```

#### 3. Docker Security

```bash
# ✅ Keep Docker updated
docker --version

# ✅ Scan images regularly
docker scan dev-proxy:latest

# ✅ Review container logs
docker compose logs dev-proxy

# ✅ Monitor resource usage
docker stats dev-proxy
```

### Dependency Management

```mermaid
graph TB
    Start([Monthly Check]) --> Base[Check nginx:alpine for updates]

    Base --> Security[Review security advisories]

    Security --> Alpine[Check Alpine security updates]
    Security --> Nginx[Check nginx security updates]

    Alpine --> Update{Updates available?}
    Nginx --> Update

    Update -->|Yes| Rebuild[Rebuild image]
    Update -->|No| Done([Next month])

    Rebuild --> Test[Run tests]
    Test --> Deploy[Deploy update]

    Deploy --> Done

    style Security fill:#ffa94d,stroke:#333,stroke-width:2px
```

**Resources:**

- **Alpine Security**: https://alpinelinux.org/
- **Nginx Security**: https://nginx.org/en/security_advisories.html
- **Docker Official Images**: https://hub.docker.com/_/nginx

### Registry Security

#### Token Management

```bash
# ✅ GOOD: Set in environment, not committed
export DO_TOKEN=dop_v1_...

# ✅ GOOD: Rotate tokens regularly (every 90 days)
# Generate new token
# Update scripts
# Revoke old token

# ❌ BAD: Hardcode in scripts
DO_TOKEN="dop_v1_..." ./scripts/push-to-registry.sh
```

#### Registry Authentication

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Script as Script
    participant Docker
    participant Registry

    Dev->>Script: Run with DO_TOKEN

    Script->>Docker: docker login
    Note over Script,Docker: --password-stdin

    Docker->>Registry: Authenticate
    Registry-->>Docker: ✓ Token valid

    Script->>Docker: docker push

    Docker->>Registry: Upload with auth
    Registry-->>Docker: ✓ Success

    Note over Dev,Registry: Token never written to disk or command history
```

## Security Checklist

### Before Deploying Locally

- [ ] Using latest image version
- [ ] `.env` file not committed to git
- [ ] No secrets in configuration files
- [ ] Firewall configured correctly
- [ ] Docker up to date
- [ ] Only binding to localhost (or local network)

### Before Building Image

- [ ] Base image version pinned (not `latest`)
- [ ] No secrets in Dockerfile
- [ ] No unnecessary packages installed
- [ ] Configuration reviewed for security
- [ ] Tests pass (`./scripts/test.sh`)

### Before Pushing to Registry

- [ ] Image scanned for vulnerabilities
- [ ] Registry token rotated recently (< 90 days)
- [ ] Correct registry specified
- [ ] Tag follows semantic versioning
- [ ] Multi-arch build tested on both platforms

### Regular Maintenance

- [ ] Monthly: Check for base image updates
- [ ] Monthly: Review security advisories
- [ ] Quarterly: Rotate registry tokens
- [ ] Quarterly: Update documentation
- [ ] Annually: Security audit

## Vulnerability Reporting

See [SECURITY.md](../SECURITY.md) in the repository root for:

- How to report vulnerabilities
- Response timeline
- Disclosure policy
- Contact information

## Security Resources

### Official Documentation

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Nginx Security](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_protocols)

### Security Tools

```bash
# Scan Docker images
docker scan dev-proxy:latest

# Audit npm packages (if using in app)
npm audit

# Check for known vulnerabilities
trivy image dev-proxy:latest
```

### Monitoring

```bash
# Check container logs for suspicious activity
docker compose logs -f dev-proxy

# Monitor resource usage
docker stats dev-proxy

# Check for failed health checks
docker inspect dev-proxy | jq '.[0].State.Health'
```

## Related Documentation

- [Architecture](Architecture) - Security architecture overview
- [Configuration](Configuration) - Secure configuration practices
- [Build Process](Build-Process) - Secure build practices
- [Troubleshooting](Troubleshooting) - Security-related issues
