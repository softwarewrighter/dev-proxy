# Request Flow

This page details how HTTP requests flow through the Dev Proxy system, including sequence diagrams for different request types.

## Table of Contents

- [Overview](#overview)
- [Frontend Request Flow](#frontend-request-flow)
- [API Request Flow](#api-request-flow)
- [Health Check Flow](#health-check-flow)
- [Error Scenarios](#error-scenarios)
- [WebSocket Support](#websocket-support)
- [Request Headers](#request-headers)

## Overview

Dev Proxy handles three main types of requests:

1. **Health Checks** (`/health`) - Direct response from nginx
2. **API Requests** (`/api/*`) - Proxied to backend with path rewrite
3. **Frontend Requests** (`/*`) - Proxied to frontend

All requests flow through nginx's routing logic based on URL path matching.

## Frontend Request Flow

### Sequence Diagram

```mermaid
sequenceDiagram
    participant Browser
    participant DevProxy as Dev Proxy<br/>(nginx:8080)
    participant Frontend as Frontend<br/>(app-frontend:3000)

    Browser->>+DevProxy: GET / HTTP/1.1
    Note over Browser,DevProxy: Host: localhost:8080
    Note over DevProxy: Match location /
    Note over DevProxy: proxy_pass to frontend

    DevProxy->>DevProxy: Add proxy headers
    Note over DevProxy: X-Real-IP, X-Forwarded-For

    DevProxy->>+Frontend: GET / HTTP/1.1
    Note over DevProxy,Frontend: Host: localhost:8080<br/>X-Real-IP: 172.17.0.1

    Frontend->>Frontend: Process request
    Note over Frontend: Generate HTML

    Frontend-->>-DevProxy: 200 OK
    Note over Frontend,DevProxy: Content-Type: text/html

    DevProxy->>DevProxy: Add security headers
    Note over DevProxy: X-Frame-Options, etc.

    DevProxy-->>-Browser: 200 OK
    Note over DevProxy,Browser: X-Frame-Options: SAMEORIGIN

    Note over Browser: Render page
```

### Step-by-Step Flow

1. **Browser Request**: User navigates to `http://localhost:8080/`
2. **Port Mapping**: Request hits Docker port mapping (8080 → container:8080)
3. **Nginx Routing**: nginx matches `location /` block
4. **Proxy Pass**: Request forwarded to `http://app-frontend:3000/`
5. **Header Addition**: Proxy headers added (X-Real-IP, X-Forwarded-For, etc.)
6. **Frontend Processing**: Frontend app processes request
7. **Response Headers**: Security headers added by nginx
8. **Return to Browser**: Response sent back through proxy

## API Request Flow

### Sequence Diagram

```mermaid
sequenceDiagram
    participant Browser
    participant DevProxy as Dev Proxy<br/>(nginx:8080)
    participant Backend as Backend<br/>(app-backend:3001)
    participant Database as Database

    Browser->>+DevProxy: GET /api/users HTTP/1.1
    Note over Browser,DevProxy: Host: localhost:8080<br/>Authorization: Bearer token123

    Note over DevProxy: Match location /api/
    Note over DevProxy: Strip /api prefix
    Note over DevProxy: proxy_pass to backend

    DevProxy->>DevProxy: Add proxy headers
    Note over DevProxy: Preserve Authorization

    DevProxy->>+Backend: GET /users HTTP/1.1
    Note over DevProxy,Backend: Host: localhost:8080<br/>Authorization: Bearer token123<br/>X-Real-IP: 172.17.0.1

    Backend->>Backend: Validate token
    Note over Backend: Process request

    Backend->>+Database: SELECT * FROM users
    Database-->>-Backend: Query results

    Backend->>Backend: Format response
    Note over Backend: JSON serialization

    Backend-->>-DevProxy: 200 OK
    Note over Backend,DevProxy: Content-Type: application/json<br/>{users: [...]}

    DevProxy->>DevProxy: Add security headers

    DevProxy-->>-Browser: 200 OK
    Note over DevProxy,Browser: X-Frame-Options: SAMEORIGIN<br/>{users: [...]}

    Note over Browser: Process JSON
```

### Path Rewriting

**Important**: The `/api` prefix is **stripped** before proxying to backend.

```
Incoming:  http://localhost:8080/api/users
Proxied:   http://app-backend:3001/users
```

This is configured in nginx:

```nginx
location /api/ {
    proxy_pass http://${APP_BACKEND_HOST}:${APP_BACKEND_PORT}/;
    # Note the trailing slash ──────────────────────────────^
}
```

### Request Examples

| Browser URL | Proxied to Backend |
|-------------|-------------------|
| `/api/users` | `/users` |
| `/api/users/123` | `/users/123` |
| `/api/v1/posts` | `/v1/posts` |
| `/api/health` | `/health` |

## Health Check Flow

### Docker Health Check Sequence

```mermaid
sequenceDiagram
    participant Docker as Docker Engine
    participant Container as Dev Proxy<br/>Container
    participant Nginx as Nginx

    loop Every 30s
        Docker->>+Container: Execute health check
        Note over Docker,Container: curl -f http://localhost:8080/health

        Container->>+Nginx: GET /health HTTP/1.1

        Note over Nginx: Match location /health
        Note over Nginx: No proxy, direct response

        Nginx-->>-Container: 200 OK
        Note over Nginx,Container: Content-Type: text/plain

        Container-->>-Docker: Exit code 0 (healthy)

        Note over Docker: Update container status
        Note over Docker: healthy
    end
```

### Health Check Configuration

**Docker Compose:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 3s
  retries: 3
  start_period: 10s
```

**Nginx Config:**
```nginx
location /health {
    access_log off;
    return 200 "OK\n";
    add_header Content-Type text/plain;
}
```

### Health Check States

```mermaid
stateDiagram-v2
    [*] --> Starting: Container starts
    Starting --> Healthy: Health check passes<br/>within start_period
    Starting --> Unhealthy: Health checks fail<br/>after 3 retries

    Healthy --> Unhealthy: Health check fails<br/>3 consecutive times
    Unhealthy --> Healthy: Health check passes

    Unhealthy --> [*]: Container stops

    note right of Starting
        start_period: 10s
        First checks may fail
        without counting as unhealthy
    end note
```

## Error Scenarios

### Backend Unavailable

```mermaid
sequenceDiagram
    participant Browser
    participant DevProxy as Dev Proxy
    participant Backend as Backend<br/>(down)

    Browser->>+DevProxy: GET /api/users

    DevProxy->>Backend: GET /users
    Note over Backend: Connection refused
    Note over Backend: Service not running

    DevProxy->>DevProxy: proxy_connect_timeout
    Note over DevProxy: 60 seconds

    Note over DevProxy: Backend unreachable

    DevProxy-->>-Browser: 502 Bad Gateway
    Note over DevProxy,Browser: nginx error page

    Note over Browser: Display error
```

### Frontend Timeout

```mermaid
sequenceDiagram
    participant Browser
    participant DevProxy as Dev Proxy
    participant Frontend as Frontend

    Browser->>+DevProxy: GET /slow-page

    DevProxy->>+Frontend: GET /slow-page

    Note over Frontend: Processing...
    Note over Frontend: Taking too long

    Note over DevProxy: proxy_read_timeout
    Note over DevProxy: 60 seconds elapsed

    DevProxy-->>-Browser: 504 Gateway Timeout

    Frontend-->>-DevProxy: 200 OK (too late)

    Note over DevProxy: Response discarded
    Note over DevProxy: Connection already closed
```

### Timeout Configuration

```nginx
proxy_connect_timeout 60s;  # Time to establish connection
proxy_send_timeout 60s;     # Time to send request to backend
proxy_read_timeout 60s;     # Time to read response from backend
```

## WebSocket Support

Dev Proxy supports WebSocket connections through the Upgrade header.

### WebSocket Flow

```mermaid
sequenceDiagram
    participant Browser
    participant DevProxy as Dev Proxy
    participant Frontend as Frontend

    Browser->>+DevProxy: GET /ws HTTP/1.1
    Note over Browser,DevProxy: Upgrade: websocket<br/>Connection: Upgrade

    Note over DevProxy: Detect Upgrade header
    Note over DevProxy: proxy_set_header Upgrade

    DevProxy->>+Frontend: GET /ws HTTP/1.1
    Note over DevProxy,Frontend: Upgrade: websocket<br/>Connection: Upgrade

    Frontend-->>DevProxy: 101 Switching Protocols
    Note over Frontend,DevProxy: Upgrade: websocket

    DevProxy-->>Browser: 101 Switching Protocols

    Note over Browser,Frontend: WebSocket connection established
    Note over Browser,Frontend: Full duplex communication

    Browser->>Frontend: WebSocket frame
    Frontend->>Browser: WebSocket frame

    Browser->>Frontend: WebSocket frame
    Frontend->>Browser: WebSocket frame

    Browser->>Frontend: Close frame
    Frontend-->>Browser: Close frame

    Note over Browser,Frontend: Connection closed
```

### WebSocket Configuration

```nginx
location / {
    proxy_pass http://${APP_FRONTEND_HOST}:${APP_FRONTEND_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_cache_bypass $http_upgrade;
}
```

**Key Headers:**

- `Upgrade: $http_upgrade` - Forwards upgrade header
- `Connection: 'upgrade'` - Maintains connection for upgrade
- `proxy_http_version 1.1` - Required for WebSocket (HTTP/1.0 doesn't support it)

### Use Cases

- **Hot Module Replacement (HMR)** - Development servers like Vite, webpack-dev-server
- **Live Reload** - Development tools
- **Real-time Features** - Chat, notifications, live updates

## Request Headers

### Headers Added by Dev Proxy

```mermaid
graph LR
    Client[Client Request] --> Nginx[Nginx Proxy]

    Nginx --> Headers{Added Headers}

    Headers --> Real[X-Real-IP<br/>Client's real IP]
    Headers --> Forwarded[X-Forwarded-For<br/>Proxy chain]
    Headers --> Proto[X-Forwarded-Proto<br/>http/https]
    Headers --> Host[Host<br/>Original host]
    Headers --> Upgrade[Upgrade<br/>websocket support]

    Real --> Upstream[Upstream Service]
    Forwarded --> Upstream
    Proto --> Upstream
    Host --> Upstream
    Upgrade --> Upstream

    style Nginx fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

### Request Header Flow

**Original Request:**
```http
GET /api/users HTTP/1.1
Host: localhost:8080
User-Agent: Mozilla/5.0
```

**Proxied Request:**
```http
GET /users HTTP/1.1
Host: localhost:8080
User-Agent: Mozilla/5.0
X-Real-IP: 172.17.0.1
X-Forwarded-For: 172.17.0.1
X-Forwarded-Proto: http
Connection: upgrade
```

### Response Headers Added

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

**Purpose:**

- **X-Frame-Options**: Prevent clickjacking
- **X-Content-Type-Options**: Prevent MIME sniffing
- **X-XSS-Protection**: Enable browser XSS filter
- **Referrer-Policy**: Control referrer information

## Complete Request Flow Diagram

```mermaid
graph TB
    Start([Browser Request]) --> Port[Port Mapping<br/>8080:8080]
    Port --> Nginx[Nginx Receives<br/>Request]

    Nginx --> Route{Route<br/>Decision}

    Route -->|/health| Health[Health Handler]
    Route -->|/api/*| API[API Location<br/>Block]
    Route -->|/*| Frontend[Frontend Location<br/>Block]

    Health --> HealthResp[Return 200 OK]

    API --> APIHeaders[Add Proxy<br/>Headers]
    APIHeaders --> APIProxy[proxy_pass to<br/>backend:3001]
    APIProxy --> APIUpstream[Backend<br/>Processing]

    Frontend --> FrontendHeaders[Add Proxy<br/>Headers]
    FrontendHeaders --> FrontendProxy[proxy_pass to<br/>frontend:3000]
    FrontendProxy --> FrontendUpstream[Frontend<br/>Processing]

    APIUpstream --> APIResponse[Backend<br/>Response]
    FrontendUpstream --> FrontendResponse[Frontend<br/>Response]

    HealthResp --> Security[Add Security<br/>Headers]
    APIResponse --> Security
    FrontendResponse --> Security

    Security --> Return([Return to<br/>Browser])

    style Nginx fill:#4a9eff,stroke:#333,stroke-width:3px,color:#fff
    style Health fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style API fill:#ffa94d,stroke:#333,stroke-width:2px,color:#fff
    style Frontend fill:#ffa94d,stroke:#333,stroke-width:2px,color:#fff
```

## Performance Characteristics

### Latency

- **Health Check**: < 1ms (local response)
- **Proxy Overhead**: ~1-5ms (header processing)
- **Total Latency**: Proxy overhead + upstream processing time

### Throughput

Nginx can handle:
- **Concurrent Connections**: 10,000+
- **Requests/Second**: Limited by upstream services, not proxy

For development purposes, performance is excellent.

## Related Documentation

- [Architecture](Architecture.md) - Overall system architecture
- [Configuration](Configuration.md) - Configuring timeouts and limits
- [Troubleshooting](Troubleshooting.md) - Debugging request flow issues
