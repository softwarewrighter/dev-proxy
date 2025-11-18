# Build Process

This page documents the build, test, and deployment workflows for Dev Proxy, including detailed diagrams and examples.

## Table of Contents

- [Overview](#overview)
- [Build Scripts](#build-scripts)
- [Local Build Workflow](#local-build-workflow)
- [Multi-Architecture Build](#multi-architecture-build)
- [Registry Push Workflow](#registry-push-workflow)
- [Testing Workflow](#testing-workflow)
- [Complete Build Pipeline](#complete-build-pipeline)

## Overview

Dev Proxy provides several build scripts for different use cases:

| Script | Purpose | Output | Registry |
|--------|---------|--------|----------|
| `build-local.sh` | Quick local build | Single platform image | No |
| `build-multiarch.sh` | Multi-platform build | arm64 + amd64 images | Optional |
| `push-to-registry.sh` | Push to registry | Multi-arch manifest | Yes |
| `build-all.sh` | Complete pipeline | All of the above | Optional |
| `test.sh` | Run tests | Test results | No |

## Build Scripts

### Script Relationships

```mermaid
graph TB
    BuildAll[build-all.sh<br/>Master Script]

    BuildAll --> Local[build-local.sh]
    BuildAll --> Multi[build-multiarch.sh]
    BuildAll --> Push[push-to-registry.sh]

    Local --> LocalImage[dev-proxy:latest<br/>Single platform]
    Multi --> MultiImage[dev-proxy:latest<br/>Multi-platform]
    Push --> Registry[Container Registry]

    Test[test.sh] -.->|uses| LocalImage

    style BuildAll fill:#4a9eff,stroke:#333,stroke-width:3px,color:#fff
    style Test fill:#ffa94d,stroke:#333,stroke-width:2px
```

### build-local.sh

**Purpose**: Quick build for immediate local use

**Features:**
- Builds for current platform only (Mac arm64 or Linux amd64)
- Fastest build option
- No registry required
- Creates `dev-proxy:latest` tag

**Usage:**
```bash
./scripts/build-local.sh
```

**Workflow:**

```mermaid
graph LR
    Start([Run Script]) --> Detect[Detect Platform<br/>uname -m]
    Detect --> Build[docker build<br/>--platform local]
    Build --> Tag[Tag as<br/>dev-proxy:latest]
    Tag --> Done([Image Ready])

    style Build fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Done fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### build-multiarch.sh

**Purpose**: Build for both Mac and Linux platforms

**Features:**
- Uses Docker Buildx
- Creates multi-platform manifest
- Builds arm64 + amd64 simultaneously
- Can push to registry or load locally

**Usage:**
```bash
# Build only (no push)
./scripts/build-multiarch.sh

# Build and push to registry
export DO_REGISTRY=registry.digitalocean.com/your-registry
./scripts/build-multiarch.sh
```

**Workflow:**

```mermaid
graph TB
    Start([Run Script]) --> Check{DO_REGISTRY<br/>set?}

    Check -->|No| Local[Local build<br/>--load]
    Check -->|Yes| Registry[Registry build<br/>--push]

    Local --> Buildx[docker buildx build<br/>--platform linux/arm64,linux/amd64]
    Registry --> Buildx

    Buildx --> ARM[Build<br/>linux/arm64]
    Buildx --> AMD[Build<br/>linux/amd64]

    ARM --> Manifest[Create<br/>Manifest]
    AMD --> Manifest

    Local -.->|Note| LocalNote[Can only load<br/>current platform<br/>locally]
    Registry --> Push[Push to<br/>Registry]

    Manifest --> Done([Complete])
    Push --> Done

    style Buildx fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Manifest fill:#ffa94d,stroke:#333,stroke-width:2px
    style Done fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### push-to-registry.sh

**Purpose**: Authenticate and push to container registry

**Features:**
- Authenticates with registry
- Pushes multi-arch manifest
- Supports any Docker-compatible registry
- Validates image exists before pushing

**Required Variables:**
- `DO_REGISTRY`: Registry URL
- `DO_TOKEN`: Registry authentication token
- `TAG`: Image tag (default: latest)

**Usage:**
```bash
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=dop_v1_abc123...
export TAG=latest

./scripts/push-to-registry.sh
```

**Workflow:**

```mermaid
sequenceDiagram
    participant User
    participant Script as push-to-registry.sh
    participant Docker
    participant Registry

    User->>Script: Run script
    Script->>Script: Validate environment
    Note over Script: DO_REGISTRY, DO_TOKEN

    Script->>Docker: docker login
    Note over Script,Docker: using DO_TOKEN

    Docker->>Registry: Authenticate
    Registry-->>Docker: Success

    Script->>Docker: docker tag
    Note over Script,Docker: dev-proxy:latest → registry/dev-proxy:TAG

    Script->>Docker: docker push
    Note over Script,Docker: registry/dev-proxy:TAG

    Docker->>Registry: Upload layers
    Registry-->>Docker: Success

    Docker-->>Script: Push complete
    Script-->>User: Success message

    Note over Script,Registry: Multi-arch manifest<br/>pushed automatically
```

### build-all.sh

**Purpose**: Complete build and deploy pipeline

**Features:**
- Runs all build steps in sequence
- Supports `--local-only` flag
- Comprehensive error handling
- Progress reporting

**Usage:**
```bash
# Local builds only
./scripts/build-all.sh --local-only

# Build and push to registry
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=dop_v1_abc123...
./scripts/build-all.sh
```

**Complete Workflow:**

```mermaid
graph TB
    Start([build-all.sh]) --> Parse{Parse<br/>Arguments}

    Parse -->|--local-only| LocalOnly[Set LOCAL_ONLY=true]
    Parse -->|No flag| CheckRegistry{DO_REGISTRY<br/>set?}

    CheckRegistry -->|No| LocalOnly
    CheckRegistry -->|Yes| ValidateVars[Validate<br/>DO_TOKEN]

    LocalOnly --> Step1[Step 1:<br/>build-local.sh]
    ValidateVars --> Step1

    Step1 --> Step1Check{Success?}
    Step1Check -->|No| Error1[ERROR:<br/>Local build failed]
    Step1Check -->|Yes| Step2[Step 2:<br/>build-multiarch.sh]

    Step2 --> Step2Check{Success?}
    Step2Check -->|No| Error2[ERROR:<br/>Multi-arch build failed]
    Step2Check -->|Yes| CheckPush{Push to<br/>registry?}

    CheckPush -->|LOCAL_ONLY=true| Success
    CheckPush -->|No| Step3[Step 3:<br/>push-to-registry.sh]

    Step3 --> Step3Check{Success?}
    Step3Check -->|No| Error3[ERROR:<br/>Push failed]
    Step3Check -->|Yes| Success([Complete])

    style Error1 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Error2 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Error3 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Success fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### test.sh

**Purpose**: Comprehensive integration testing

**Features:**
- Creates mock backend/frontend services
- Tests all routing patterns
- Validates security headers
- Automatic cleanup
- No external dependencies

**Usage:**
```bash
./scripts/test.sh
```

**Test Workflow:**

```mermaid
graph TB
    Start([test.sh]) --> Setup[Setup Phase]

    Setup --> CreateNetwork[Create test network]
    CreateNetwork --> StartBackend[Start mock backend<br/>nginx on :3001]
    StartBackend --> StartFrontend[Start mock frontend<br/>nginx on :3000]
    StartFrontend --> StartProxy[Start dev-proxy<br/>on :8081]

    StartProxy --> WaitHealthy[Wait for<br/>health checks]

    WaitHealthy --> Test1[Test 1:<br/>Health endpoint]
    Test1 --> Test2[Test 2:<br/>Frontend routing]
    Test2 --> Test3[Test 3:<br/>API routing]
    Test3 --> Test4[Test 4:<br/>Security headers]
    Test4 --> Test5[Test 5:<br/>Environment vars]

    Test5 --> Cleanup[Cleanup Phase]

    Cleanup --> StopProxy[Stop dev-proxy]
    StopProxy --> StopFrontend[Stop frontend]
    StopFrontend --> StopBackend[Stop backend]
    StopBackend --> RemoveNetwork[Remove test network]

    RemoveNetwork --> Report{All tests<br/>passed?}
    Report -->|Yes| Success([SUCCESS])
    Report -->|No| Failure([FAILURE])

    style Success fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style Failure fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
```

## Local Build Workflow

### Development Cycle

```mermaid
graph LR
    Edit[Edit Code] --> Build[./scripts/build-local.sh]
    Build --> Test[./scripts/test.sh]
    Test --> Verify{Tests<br/>Pass?}

    Verify -->|No| Debug[Debug Issues]
    Verify -->|Yes| Deploy[Deploy Locally<br/>docker compose up]

    Debug --> Edit

    Deploy --> UseApp[Use Application]
    UseApp --> MoreChanges{More<br/>Changes?}

    MoreChanges -->|Yes| Edit
    MoreChanges -->|No| Done([Done])

    style Test fill:#ffa94d,stroke:#333,stroke-width:2px
    style Done fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### Quick Iteration

For rapid development, use volume mounts:

```yaml
# docker-compose.override.yml
services:
  dev-proxy:
    volumes:
      - ./nginx.conf.template:/etc/nginx/templates/default.conf.template
```

```bash
# After editing nginx.conf.template:
docker compose exec dev-proxy nginx -s reload
# No rebuild needed!
```

## Multi-Architecture Build

### Platform Support

```mermaid
graph TB
    subgraph "Build Machine"
        Buildx[Docker Buildx<br/>Builder]
    end

    subgraph "Target Platforms"
        ARM[linux/arm64<br/>Apple Silicon<br/>M1/M2/M3]
        AMD[linux/amd64<br/>Intel/AMD<br/>x86_64]
    end

    Buildx --> ARM
    Buildx --> AMD

    ARM --> ARMLayers[Nginx Binary<br/>arm64]
    AMD --> AMDLayers[Nginx Binary<br/>amd64]

    ARMLayers --> Manifest[Multi-Arch<br/>Manifest]
    AMDLayers --> Manifest

    style Buildx fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style Manifest fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### Buildx Setup

```bash
# Create buildx builder (one-time setup)
docker buildx create --name multiarch-builder --use
docker buildx inspect --bootstrap

# Verify platforms
docker buildx ls
```

### Build Process Details

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Buildx as Docker Buildx
    participant ARM as ARM64 Builder
    participant AMD as AMD64 Builder
    participant Registry

    Dev->>Buildx: docker buildx build
    Note over Dev,Buildx: --platform linux/arm64,linux/amd64

    par Parallel Builds
        Buildx->>ARM: Build arm64 image
        Buildx->>AMD: Build amd64 image
    end

    ARM->>ARM: FROM nginx:alpine
    Note over ARM: arm64 variant

    AMD->>AMD: FROM nginx:alpine
    Note over AMD: amd64 variant

    ARM->>ARM: COPY files
    Note over ARM: RUN apk add

    AMD->>AMD: COPY files
    Note over AMD: RUN apk add

    ARM-->>Buildx: arm64 image ready
    AMD-->>Buildx: amd64 image ready

    Buildx->>Buildx: Create manifest
    Note over Buildx: combining both images

    alt Push to Registry
        Buildx->>Registry: Push manifest
        Buildx->>Registry: Push arm64 layers
        Buildx->>Registry: Push amd64 layers
    else Load Locally
        Buildx->>Buildx: Load current platform
        Note over Buildx: to local Docker
    end

    Buildx-->>Dev: Build complete
```

## Registry Push Workflow

### Supported Registries

Dev Proxy can push to any Docker-compatible registry:

```mermaid
graph TB
    Image[dev-proxy:latest<br/>Multi-arch]

    Image --> DO[Digital Ocean<br/>Container Registry]
    Image --> DockerHub[Docker Hub]
    Image --> GCR[Google Container<br/>Registry]
    Image --> ECR[AWS ECR]
    Image --> GHCR[GitHub Container<br/>Registry]

    style Image fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

### Push Process

```mermaid
graph TB
    Start([Push Script]) --> Auth[Authenticate<br/>docker login]

    Auth --> CheckImage{Image<br/>exists?}
    CheckImage -->|No| Error1[ERROR:<br/>Build image first]
    CheckImage -->|Yes| Tag[Tag image<br/>registry/name:tag]

    Tag --> Push[docker push]

    Push --> Layers[Upload Layers]

    Layers --> Layer1[Push base layer<br/>nginx:alpine]
    Layers --> Layer2[Push curl layer]
    Layers --> Layer3[Push config layer]

    Layer1 --> CheckCache1{Layer in<br/>registry?}
    Layer2 --> CheckCache2{Layer in<br/>registry?}
    Layer3 --> CheckCache3{Layer in<br/>registry?}

    CheckCache1 -->|Yes| Skip1[Skip: Layer exists]
    CheckCache1 -->|No| Upload1[Upload layer]

    CheckCache2 -->|Yes| Skip2[Skip: Layer exists]
    CheckCache2 -->|No| Upload2[Upload layer]

    CheckCache3 -->|Yes| Skip3[Skip: Layer exists]
    CheckCache3 -->|No| Upload3[Upload layer]

    Skip1 --> Manifest
    Upload1 --> Manifest
    Skip2 --> Manifest
    Upload2 --> Manifest
    Skip3 --> Manifest
    Upload3 --> Manifest

    Manifest[Push manifest<br/>with platform info]

    Manifest --> Done([Push Complete])

    style Error1 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style Done fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### Registry Configuration Examples

#### Digital Ocean

```bash
export DO_REGISTRY=registry.digitalocean.com/your-registry
export DO_TOKEN=dop_v1_your_token_here
export TAG=latest

./scripts/push-to-registry.sh
```

#### Docker Hub

```bash
export DO_REGISTRY=docker.io/yourusername
export DO_TOKEN=your_docker_hub_token
export TAG=v1.0.0

./scripts/push-to-registry.sh
```

#### GitHub Container Registry

```bash
export DO_REGISTRY=ghcr.io/yourusername
export DO_TOKEN=ghp_your_github_token
export TAG=latest

./scripts/push-to-registry.sh
```

## Testing Workflow

### Test Architecture

```mermaid
graph TB
    subgraph "Test Network: dev-proxy-test-network"
        Proxy[dev-proxy<br/>:8081]
        Backend[mock-backend<br/>nginx:alpine<br/>:3001]
        Frontend[mock-frontend<br/>nginx:alpine<br/>:3000]

        Proxy -->|/api/*| Backend
        Proxy -->|/*| Frontend
    end

    TestScript[test.sh] -->|curl requests| Proxy

    Backend -->|return| BackendResp["backend response"]
    Frontend -->|return| FrontendResp["frontend response"]

    style Proxy fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    style TestScript fill:#ffa94d,stroke:#333,stroke-width:2px
```

### Test Sequence

```mermaid
sequenceDiagram
    participant Script as test.sh
    participant Proxy as dev-proxy
    participant Backend as mock-backend
    participant Frontend as mock-frontend

    Script->>Script: Create test network

    Script->>Backend: Start container
    Note over Backend: Serve "backend" on :3001

    Script->>Frontend: Start container
    Note over Frontend: Serve "frontend" on :3000

    Script->>Proxy: Start container
    Note over Proxy: Connect to test network

    Script->>Proxy: Wait for health check
    Proxy-->>Script: Healthy

    Note over Script,Proxy: Test 1: Health Check

    Script->>Proxy: GET /health
    Proxy-->>Script: 200 OK

    Note over Script,Frontend: Test 2: Frontend Routing

    Script->>Proxy: GET /
    Proxy->>Frontend: GET /
    Frontend-->>Proxy: "frontend"
    Proxy-->>Script: "frontend"

    Note over Script,Backend: Test 3: API Routing

    Script->>Proxy: GET /api/test
    Proxy->>Backend: GET /test
    Backend-->>Proxy: "backend"
    Proxy-->>Script: "backend"

    Note over Script,Proxy: Test 4: Security Headers

    Script->>Proxy: GET / (check headers)
    Proxy-->>Script: Headers include
    Note over Proxy,Script: X-Frame-Options, etc.

    Note over Script,Proxy: Test 5: Environment Variables

    Script->>Proxy: Verify config
    Note over Proxy: contains correct hosts

    Script->>Script: All tests passed!

    Script->>Proxy: Stop container
    Script->>Frontend: Stop container
    Script->>Backend: Stop container
    Script->>Script: Remove network

    Script->>Script: Report results
```

### Test Validation

```mermaid
graph TB
    Start([Run Tests]) --> T1{Health Check<br/>/health}

    T1 -->|Pass| T2{Frontend<br/>/ → frontend}
    T1 -->|Fail| F1[FAIL:<br/>Proxy not healthy]

    T2 -->|Pass| T3{API Routing<br/>/api/* → backend}
    T2 -->|Fail| F2[FAIL:<br/>Frontend routing broken]

    T3 -->|Pass| T4{Security Headers<br/>Present?}
    T3 -->|Fail| F3[FAIL:<br/>API routing broken]

    T4 -->|Pass| T5{Environment<br/>Variables OK?}
    T4 -->|Fail| F4[FAIL:<br/>Security headers missing]

    T5 -->|Pass| Success([ALL TESTS PASSED])
    T5 -->|Fail| F5[FAIL:<br/>Config error]

    style Success fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
    style F1 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style F2 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style F3 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style F4 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
    style F5 fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#fff
```

## Complete Build Pipeline

### Full Development to Production Flow

```mermaid
graph TB
    Dev[Development] --> Code[Write Code]
    Code --> LocalBuild[./scripts/build-local.sh]
    LocalBuild --> LocalTest[./scripts/test.sh]

    LocalTest --> TestPass{Tests<br/>Pass?}
    TestPass -->|No| Debug[Debug & Fix]
    Debug --> Code

    TestPass -->|Yes| Commit[Git Commit]
    Commit --> MultiArch[./scripts/build-multiarch.sh]

    MultiArch --> BuildPass{Build<br/>Success?}
    BuildPass -->|No| Debug
    BuildPass -->|Yes| Push[./scripts/push-to-registry.sh]

    Push --> PushPass{Push<br/>Success?}
    PushPass -->|No| CheckCreds[Check Credentials]
    CheckCreds --> Push

    PushPass -->|Yes| Registry[Image in Registry]
    Registry --> Deploy[Deploy to Environments]

    Deploy --> DevEnv[Development<br/>Environment]
    Deploy --> StagingEnv[Staging<br/>Environment]
    Deploy --> ProdEnv[Production<br/>Environment]

    DevEnv --> Monitor[Monitor & Verify]
    StagingEnv --> Monitor
    ProdEnv --> Monitor

    Monitor --> Issues{Issues<br/>Found?}
    Issues -->|Yes| Hotfix[Create Hotfix]
    Issues -->|No| Done([Deployment Complete])

    Hotfix --> Code

    style Done fill:#51cf66,stroke:#333,stroke-width:2px,color:#fff
```

### Automated Pipeline (CI/CD)

```mermaid
graph LR
    Trigger[Git Push] --> CI[CI Pipeline]

    CI --> Lint[Lint Configs]
    Lint --> Build[Build Image]
    Build --> Test[Run Tests]
    Test --> Scan[Security Scan]

    Scan --> Branch{Which<br/>Branch?}

    Branch -->|develop| TagDev[Tag: dev-latest]
    Branch -->|main| TagProd[Tag: latest]
    Branch -->|tag v*| TagVer[Tag: version]

    TagDev --> PushDev[Push to Registry]
    TagProd --> PushProd[Push to Registry]
    TagVer --> PushVer[Push to Registry]

    PushDev --> DeployDev[Deploy Dev]
    PushProd --> DeployStaging[Deploy Staging]
    PushVer --> DeployProd[Deploy Production]

    style CI fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
```

## Best Practices

### 1. Development

- Use `build-local.sh` for quick iterations
- Run `test.sh` before committing
- Use volume mounts for config changes

### 2. Testing

- Always test locally before pushing
- Validate on both Mac and Linux if possible
- Check security headers in tests

### 3. Registry

- Use semantic versioning for tags
- Keep `latest` tag for current stable
- Tag commits with version numbers

### 4. Security

- Scan images before deploying: `docker scan dev-proxy:latest`
- Keep base image updated
- Review nginx security advisories

## Related Documentation

- [Architecture](Architecture) - Understanding what's being built
- [Configuration](Configuration) - Build-time configuration
- [Security](Security) - Security considerations in builds
- [Troubleshooting](Troubleshooting) - Build issues and solutions
