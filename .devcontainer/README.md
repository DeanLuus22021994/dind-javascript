# Enhanced Docker in Docker JavaScript Development Environment

This is a comprehensive Docker-in-Docker development environment optimized for JavaScript/Node.js development with additional services for full-stack development.

## 🚀 Features

### Core Services
- **Docker in Docker** - Full Docker daemon with BuildKit support
- **BuildKit** - Advanced build caching and multi-platform builds
- **Redis** - In-memory data store for caching and sessions
- **PostgreSQL** - Relational database for development
- **Docker Registry** - Local container registry for testing

### Development Tools
- **Node.js 20** with npm and yarn
- **TypeScript** support with ts-node
- **Testing frameworks** (Jest, Mocha, Cypress, Playwright)
- **Build tools** (Webpack, Vite, esbuild)
- **Code quality** (ESLint, Prettier)
- **Monitoring tools** (ctop, lazydocker)

### VS Code Extensions (30+)
- Language support (JavaScript, TypeScript, JSON, YAML, Markdown)
- Docker and Kubernetes tools
- Database tools (PostgreSQL, Redis)
- Git and GitHub integration
- Testing and debugging tools
- Code quality and formatting tools

## 🏗️ Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   DevContainer  │  │    BuildKit     │  │      Redis      │
│                 │  │                 │  │                 │
│ • Node.js       │  │ • Build Cache   │  │ • Session Store │
│ • Development   │  │ • Multi-arch    │  │ • App Cache     │
│ • Tools         │  │ • Advanced      │  │ • Job Queue     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
┌─────────────────┐  ┌─────────────────┐
│   PostgreSQL    │  │   Registry      │
│                 │  │                 │
│ • Development   │  │ • Local Images  │
│ • Database      │  │ • Testing       │
│ • Sample Data   │  │ • Private Repo  │
└─────────────────┘  └─────────────────┘
```

## 🚀 Quick Start

### 1. Open in VS Code
```bash
code .
# VS Code will prompt to reopen in container
```

### 2. Check Environment Status
```bash
./dev-status.sh
```

### 3. Run Health Checks
```bash
health
```

### 4. Start Development
```bash
npm install
npm run dev
```

## 🔧 Available Services

| Service     | Port | Purpose             | Connection             |
| ----------- | ---- | ------------------- | ---------------------- |
| Main App    | 3000 | Application server  | http://localhost:3000  |
| Secondary   | 3001 | Additional services | http://localhost:3001  |
| API/GraphQL | 4000 | API endpoint        | http://localhost:4000  |
| Registry    | 5000 | Docker registry     | http://localhost:5000  |
| Alt HTTP    | 8080 | Alternative HTTP    | http://localhost:8080  |
| Node Debug  | 9229 | Node.js debugger    | localhost:9229         |
| Redis       | 6379 | Cache/Sessions      | redis-cli -h localhost |
| PostgreSQL  | 5432 | Database            | psql-dev               |

## 🛠️ Development Commands

### Package Management
```bash
npm install              # Install dependencies
npm start               # Start application
npm test                # Run tests
npm run test:watch      # Run tests in watch mode
npm run test:coverage   # Run tests with coverage
```

### Docker Commands
```bash
dc up                   # Start all services
dc down                 # Stop all services
dc logs                 # View service logs
dc ps                   # List running services
dps                     # Formatted docker ps
```

### Database Commands
```bash
psql-dev                # Connect to PostgreSQL
redis-cli               # Connect to Redis
```

### Build Commands
```bash
docker buildx bake      # Build with cache
build-local            # Build and load locally
push-local             # Push to local registry
```

## 📊 Monitoring

### View Environment Status
```bash
./dev-status.sh
```

### Health Checks
```bash
health                  # Run all health checks
```

### Service Logs
```bash
dc logs -f             # Follow all logs
dc logs redis          # View Redis logs
logs-app               # View application logs
logs-error             # View error logs
```

### Resource Monitoring
```bash
ctop                   # Container top
lazydocker            # Docker TUI
htop                  # System monitor
```

## 🗄️ Data Persistence

### Volumes
- `dind-var-lib-docker` - Docker daemon data
- `dind-buildkit-cache` - Build cache (tmpfs for performance)
- `dind-npm-cache` - npm package cache
- `dind-yarn-cache` - Yarn package cache
- `dind-node-modules` - Project dependencies
- `dind-vscode-extensions` - VS Code extensions
- `dind-redis-data` - Redis data
- `dind-postgres-data` - PostgreSQL data
- `dind-registry-data` - Docker registry data

### Cache Locations
- npm: `/cache/npm`
- Yarn: `/cache/yarn`
- BuildKit: `/cache/buildkit`
- Docker: `/cache/docker`

## 🔒 Security Features

- Secure container configuration
- Isolated network (192.168.100.0/24)
- Non-root user (vscode)
- Proper file permissions
- Capability restrictions

## 🧪 Testing

### Unit Tests
```bash
npm test                # Run all tests
npm run test:watch      # Watch mode
npm run test:coverage   # With coverage
```

### Integration Tests
```bash
# Database tests
npm run test:db

# Redis tests
npm run test:redis

# API tests
npm run test:api
```

### End-to-End Tests
```bash
# Cypress
npx cypress open

# Playwright
npx playwright test
```

## 🚀 Performance Optimizations

### Build Cache
- BuildKit cache mounted as tmpfs
- Multi-layer caching strategy
- Persistent npm/yarn caches

### Network Optimization
- Custom bridge network
- Optimized MTU settings
- Service discovery via container names

### Resource Limits
- Redis memory limit (256MB)
- Optimized PostgreSQL settings
- Efficient log rotation

## 📚 Documentation

### Configuration Files
- `.devcontainer/devcontainer.json` - Main configuration
- `.devcontainer/docker-compose.yml` - Service definitions
- `.devcontainer/Dockerfile` - Container image
- `docker-bake.hcl` - Build configuration

### Scripts
- `.devcontainer/setup.sh` - Initial setup
- `.devcontainer/post-start.sh` - Post-start configuration
- `scripts/health-check.sh` - Health monitoring
- `dev-status.sh` - Environment dashboard

## 🔧 Customization

### Override Services
Create `docker-compose.override.yml`:
```yaml
version: '3.8'
services:
  devcontainer:
    environment:
      - DEBUG=*
      - LOG_LEVEL=debug
```

### Add Custom Tools
Edit `.devcontainer/Dockerfile`:
```dockerfile
# Add your custom tools
RUN apt-get update && apt-get install -y your-tool
```

### Environment Variables
Add to `.devcontainer/devcontainer.json`:
```json
{
  "remoteEnv": {
    "CUSTOM_VAR": "value"
  }
}
```

## 🐛 Troubleshooting

### Common Issues

#### Services not starting
```bash
dc down && dc up -d
health
```

#### Build cache issues
```bash
docker buildx prune
docker system prune -f
```

#### Permission issues
```bash
sudo chown -R vscode:vscode /workspace
```

#### Network connectivity
```bash
docker network ls
docker network inspect dind-javascript_devcontainer-network
```

### Logs and Debugging

#### Service logs
```bash
dc logs service-name
```

#### Container inspection
```bash
docker inspect container-name
```

#### Network debugging
```bash
docker exec devcontainer ping redis
docker exec devcontainer nslookup postgres
```

## 🆘 Support

For issues or improvements:
1. Check logs: `dc logs`
2. Run health checks: `health`
3. View environment: `./dev-status.sh`
4. Reset environment: `dc down && dc up -d`

## 📝 License

This development environment configuration is provided as-is for development purposes.
