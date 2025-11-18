# Architecture

This page describes the architecture of the Dev Proxy system, including its components, design decisions, and deployment patterns.

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Component Architecture](#component-architecture)
- [Network Architecture](#network-architecture)
- [Container Architecture](#container-architecture)
- [Design Decisions](#design-decisions)

## Overview

Dev Proxy is a containerized nginx reverse proxy designed for local development. It provides a single entry point for accessing both frontend and backend services of a containerized application.

### Key Principles

1. **Simplicity** - Minimal configuration, maximum utility
2. **Flexibility** - Works with any containerized app following standard patterns
3. **Portability** - Multi-arch builds support both Mac and Linux development
4. **Isolation** - Runs in its own container on the app's network

## System Architecture

```mermaid
graph TB
    subgraph "Developer Machine"
        Browser[Web Browser]
        Docker[Docker Engine]

        subgraph "Dev Proxy Container"
            Nginx[Nginx Server<br/>:8080]
            Config[nginx.conf]
            Health[Health Check<br/>/health]
            Nginx --> Config
            Nginx --> Health
        end

        subgraph "App Network"
            Backend[Backend Service<br/>:3001]
            Frontend[Frontend Service<br/>:3000]
            Database[(Database)]
            Cache[(Redis/Cache)]
        end

        Browser -->|localhost:8080| Nginx
        Nginx -->|/api/*| Backend
        Nginx -->|/*| Frontend
        Backend --> Database
        Backend --> Cache
        Frontend -.->|Development<br/>HMR| Browser

        Docker --> Nginx
        Docker --> Backend
        Docker --> Frontend
    end

    style Nginx fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Backend fill:#68c468,stroke:#333,stroke-width:2px,color:#fff
    style Frontend fill:#68c468,stroke:#333,stroke-width:2px,color:#fff
    style Health fill:#ffa94d,stroke:#333,stroke-width:1px
```

## Component Architecture

### 1. Nginx Reverse Proxy

The core component is nginx running in Alpine Linux.

```mermaid
graph LR
    subgraph "Nginx Container"
        direction TB
        Master["Nginx Master<br/>Process<br/>PID 1"]
        Worker1["Worker Process<br/>nginx user"]
        Worker2["Worker Process<br/>nginx user"]

        Master --> Worker1
        Master --> Worker2

        subgraph "Configuration"
            Template["nginx.conf.template"]
            Env["Environment<br/>Variables"]
            Final["Final Config<br/>/etc/nginx/conf.d/default.conf"]

            Template --> Final
            Env --> Final
        end

        Worker1 --> Final
        Worker2 --> Final
    end

    style Master fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Worker1 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Worker2 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Final fill:#ffa94d,stroke:#333,stroke-width:2px
```

**Key Features:**

- **Master Process**: Runs as root (standard for containerized nginx)
- **Worker Processes**: Run as unprivileged `nginx` user
- **Template Processing**: Environment variables substituted at startup
- **Health Monitoring**: Built-in health check endpoint

### 2. Routing Layer

Request routing is based on URL path patterns.

```mermaid
graph TD
    Request[Incoming Request] --> Router{Path Match}

    Router -->|/health| HealthHandler[Health Handler<br/>Return 200 OK]
    Router -->|/api/*| APIProxy[API Proxy<br/>→ Backend]
    Router -->|/* other| FrontendProxy[Frontend Proxy<br/>→ Frontend]

    APIProxy --> Backend[app-backend:3001]
    FrontendProxy --> Frontend[app-frontend:3000]

    style Router fill:#ffa94d,stroke:#333,stroke-width:2px
    style HealthHandler fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style APIProxy fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style FrontendProxy fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

**Routing Rules:**

1. `/health` - Local health check (no proxy)
2. `/api/*` - Proxied to backend with path rewrite (strips `/api`)
3. `/*` - All other paths proxied to frontend

### 3. Configuration Layer

```mermaid
graph LR
    subgraph "Build Time"
        Dockerfile[Dockerfile]
        Template[nginx.conf.template]
    end

    subgraph "Runtime"
        EnvFile[.env File]
        EnvVars[Environment<br/>Variables]
        Compose[docker-compose.yml]
    end

    subgraph "Container Startup"
        Entrypoint[Nginx Entrypoint]
        Envsubst[envsubst<br/>Template Processing]
        FinalConfig[Final Config<br/>/etc/nginx/conf.d/]
    end

    Dockerfile --> Template
    EnvFile --> Compose
    Compose --> EnvVars
    EnvVars --> Entrypoint
    Template --> Entrypoint
    Entrypoint --> Envsubst
    Envsubst --> FinalConfig

    style Envsubst fill:#ffa94d,stroke:#333,stroke-width:2px
    style FinalConfig fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

## Network Architecture

### Docker Network Topology

```mermaid
graph TB
    subgraph "Host Machine"
        HostPort[localhost:8080]

        subgraph "App Docker Network"
            Proxy[dev-proxy<br/>:8080]
            Backend[app-backend<br/>:3001]
            Frontend[app-frontend<br/>:3000]
            DB[(Database<br/>:5432)]

            Proxy -.->|internal| Backend
            Proxy -.->|internal| Frontend
            Backend -.->|internal| DB
        end

        HostPort -->|port mapping| Proxy
    end

    style Proxy fill:#4a9eff,stroke:#333,stroke-width:3px,color:#fff
    style Backend fill:#68c468,stroke:#333,stroke-width:2px,color:#fff
    style Frontend fill:#68c468,stroke:#333,stroke-width:2px,color:#fff
    style DB fill:#845ef7,stroke:#333,stroke-width:2px,color:#fff
```

**Network Characteristics:**

- **External Network**: App's existing Docker network (configured via `APP_NETWORK`)
- **Port Mapping**: Only dev-proxy exposes port to host
- **Internal Communication**: All service-to-service traffic stays within Docker network
- **DNS Resolution**: Docker's built-in DNS resolves service names

### Multi-App Support

Dev Proxy can connect to different app networks by changing configuration:

```mermaid
graph TB
    subgraph "Host"
        Proxy[dev-proxy]
    end

    subgraph "Network 1: crudibase-network"
        Backend1[crudibase-backend]
        Frontend1[crudibase-frontend]
    end

    subgraph "Network 2: cruditrack-network"
        Backend2[cruditrack-backend]
        Frontend2[cruditrack-frontend]
    end

    Proxy -.->|Config 1| Backend1
    Proxy -.->|Config 1| Frontend1
    Proxy -.->|Config 2| Backend2
    Proxy -.->|Config 2| Frontend2

    style Proxy fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

**Note**: Dev Proxy can only connect to one app network at a time. Switch by updating `.env` and restarting.

## Container Architecture

### Image Layers

```mermaid
graph TB
    Base[nginx:1.25.3-alpine] --> Layer1[+ curl package]
    Layer1 --> Layer2[+ nginx.conf.template]
    Layer2 --> Layer3[+ EXPOSE 8080]
    Layer3 --> Layer4[+ HEALTHCHECK]
    Layer4 --> Final[dev-proxy:latest]

    style Base fill:#845ef7,stroke:#333,stroke-width:2px,color:#fff
    style Final fill:#4a9eff,stroke:#333,stroke-width:3px,color:#fff
```

**Image Size**: ~43MB (Alpine-based)

### Multi-Architecture Build

```mermaid
graph TB
    Source[Source Code] --> Builder[Docker Buildx]

    Builder --> ARM[linux/arm64<br/>Mac M1/M2/M3]
    Builder --> AMD[linux/amd64<br/>Linux/Intel Mac]

    ARM --> Manifest[Multi-arch<br/>Manifest]
    AMD --> Manifest

    Manifest --> Registry[Container<br/>Registry]

    Registry --> MacPull[Mac Pull<br/>→ arm64]
    Registry --> LinuxPull[Linux Pull<br/>→ amd64]

    style Builder fill:#ffa94d,stroke:#333,stroke-width:2px
    style Manifest fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

### Runtime Architecture

```mermaid
graph TB
    subgraph "Container Runtime"
        Init[Container Init<br/>PID 1] --> NginxMaster[Nginx Master<br/>root user]

        NginxMaster --> Worker1[Worker 1<br/>nginx user]
        NginxMaster --> Worker2[Worker 2<br/>nginx user]

        subgraph "Filesystem"
            Conf[/etc/nginx/]
            Logs[/var/log/nginx/]
            Cache[/var/cache/nginx/]
            Run[/var/run/]
        end

        Worker1 --> Conf
        Worker2 --> Conf
        Worker1 --> Logs
        Worker2 --> Logs
        Worker1 --> Cache
        Worker2 --> Cache
    end

    HealthCheck[Docker<br/>Health Check] -.->|curl localhost:8080/health| Worker1

    style NginxMaster fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Worker1 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Worker2 fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

## Design Decisions

### 1. Why nginx?

- **Proven**: Battle-tested reverse proxy
- **Lightweight**: Small footprint, low resource usage
- **Fast**: Excellent performance for proxying
- **Simple**: Well-understood configuration

### 2. Why Alpine Linux?

- **Small**: Minimal base image (~7MB base)
- **Secure**: Smaller attack surface
- **Fast**: Quick to build and deploy

### 3. Why HTTP only (no HTTPS)?

- **Local Dev**: Designed for localhost use only
- **Simplicity**: No certificate management needed
- **Performance**: Lower overhead for development

**Important**: Never expose this proxy to external networks or production environments.

### 4. Why Template-Based Config?

- **Flexibility**: Same image works for any app
- **Simplicity**: No rebuilding to change configuration
- **Portability**: Configuration via environment variables

### 5. Why External Network?

- **Integration**: Connects to existing app infrastructure
- **Isolation**: Doesn't require app changes
- **Flexibility**: Easy to add/remove without affecting app

## Port Standardization

Dev Proxy assumes standardized internal ports:

| Service | Port | Protocol |
|---------|------|----------|
| Frontend | 3000 | HTTP |
| Backend | 3001 | HTTP |
| Proxy (external) | 8080 | HTTP |
| Proxy (internal) | 8080 | HTTP |

**Benefits:**

- Consistent configuration across all apps
- Predictable routing rules
- Simplified documentation

## Related Documentation

- [Request Flow](Request-Flow.md) - See how requests flow through the system
- [Configuration](Configuration.md) - Detailed configuration options
- [Build Process](Build-Process.md) - How images are built and deployed
- [Security](Security.md) - Security architecture and considerations
