#!/bin/bash
# Enhanced Docker in Docker environment setup
# Updated to use modular utilities

set -euo pipefail

# Source our modular utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=core-utils.sh
source "$SCRIPT_DIR/core-utils.sh"

# shellcheck disable=SC1091
# shellcheck source=docker-utils.sh
source "$SCRIPT_DIR/docker-utils.sh"

# shellcheck disable=SC1091
# shellcheck source=service-utils.sh
source "$SCRIPT_DIR/service-utils.sh"

# Load environment configuration
load_env_file "$(dirname "$SCRIPT_DIR")/config/performance.env"

log_info "Setting up enhanced Docker in Docker environment..."

# Check Docker system first
if ! check_docker_system; then
    log_error "Docker system check failed"
    exit 1
fi

# Set up NPM/Yarn cache with proper permissions
echo "📦 Configuring package managers..."
mkdir -p /cache/npm /cache/yarn
chown -R vscode:vscode /cache/npm /cache/yarn
npm config set cache /cache/npm
yarn config set cache-folder /cache/yarn

# Configure global npm packages
echo "🌐 Installing global npm packages..."
npm install -g \
  nodemon \
  pm2 \
  create-react-app \
  @vue/cli \
  @angular/cli \
  vite \
  webpack-cli \
  typescript \
  ts-node \
  jest \
  mocha \
  cypress \
  playwright \
  eslint \
  prettier \
  @storybook/cli

# Create docker bake configuration
echo "🥧 Creating Docker Bake configuration..."
cat > /workspace/docker-bake.hcl << 'EOF'
variable "CACHE_FROM" {
  default = "type=local,src=/cache/buildkit"
}

variable "CACHE_TO" {
  default = "type=local,dest=/cache/buildkit,mode=max"
}

variable "REGISTRY" {
  default = "localhost:5000"
}

group "default" {
  targets = ["app"]
}

target "app" {
  dockerfile = "Dockerfile"
  cache-from = ["${CACHE_FROM}"]
  cache-to = ["${CACHE_TO}"]
  output = ["type=docker"]
  tags = ["${REGISTRY}/app:latest"]
}

target "app-prod" {
  inherits = ["app"]
  target = "production"
  tags = ["${REGISTRY}/app:latest", "${REGISTRY}/app:production"]
}

target "app-dev" {
  inherits = ["app"]
  target = "development"
  tags = ["${REGISTRY}/app:dev"]
}
EOF

# Create buildkit daemon config
echo "⚙️  Configuring BuildKit daemon..."
mkdir -p /etc/buildkit
cat > /etc/buildkit/buildkitd.toml << 'EOF'
[worker.oci]
  enabled = true
  platforms = [ "linux/amd64", "linux/arm64" ]

[worker.containerd]
  enabled = true
  platforms = [ "linux/amd64", "linux/arm64" ]

[cache]
  [cache.local]
    enabled = true
    rootdir = "/cache/buildkit"

[registry."localhost:5000"]
  http = true
  insecure = true
EOF

# Create helpful aliases - commented out for non-interactive use
echo "🔗 Skipping alias creation for non-interactive use..."
cat >> /home/vscode/.bashrc << 'EOF'

# Docker aliases - commented out for non-interactive use
# alias dc='docker-compose'
# alias dcu='docker-compose up'
# alias dcd='docker-compose down'
# alias dcl='docker-compose logs'
# alias dps='docker ps'
# alias di='docker images'
# alias dv='docker volume ls'
# alias dn='docker network ls'

# Kubernetes aliases - commented out for non-interactive use
# alias k='kubectl'
# alias kgp='kubectl get pods'
# alias kgs='kubectl get services'
# alias kgd='kubectl get deployments'

# Git aliases - commented out for non-interactive use
# alias gs='git status'
# alias ga='git add'
# alias gc='git commit'
# alias gp='git push'
# alias gl='git log --oneline'

# Node.js aliases - commented out for non-interactive use
# alias ni='npm install'
# alias ns='npm start'
# alias nt='npm test'
# alias nb='npm run build'
# alias yi='yarn install'
# alias ys='yarn start'
# alias yt='yarn test'
# alias yb='yarn build'

# Redis CLI shortcut - commented out for non-interactive use
# alias redis='redis-cli -h redis'

# PostgreSQL shortcuts - commented out for non-interactive use
# alias psql-dev='psql -h postgres -U devuser -d devdb'

# Registry operations - commented out for non-interactive use
# alias docker-push-local='docker tag $1 localhost:5000/$1 && docker push localhost:5000/$1'
EOF

# Set up Git configuration
echo "🔧 Configuring Git..."
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input
git config --global core.editor "code --wait"

# Create workspace directories
echo "📁 Creating workspace directories..."
mkdir -p /workspace/{src,tests,docs,scripts,config,dist,build}

# Set up health check scripts
echo "🏥 Creating health check scripts..."
cat > /workspace/scripts/health-check.sh << 'EOF'
#!/bin/bash
echo "🔍 Running health checks..."

echo "📊 Docker status:"
docker version --format 'Version: {{.Server.Version}}'

echo "🏗️  BuildKit status:"
docker buildx ls

echo "📦 Redis status:"
redis-cli -h redis ping

echo "🐘 PostgreSQL status:"
pg_isready -h postgres -U devuser

echo "🗄️  Registry status:"
curl -s http://registry:5000/v2/ | jq .

echo "✅ All services are healthy!"
EOF

chmod +x /workspace/scripts/health-check.sh

# Install additional development tools
echo "🛠️  Installing additional tools..."
apt-get update && apt-get install -y --no-install-recommends \
  postgresql-client \
  redis-tools \
  jq \
  tree \
  htop \
  ncdu \
  net-tools \
  telnet

# Create sample configuration files
echo "📄 Creating sample configuration files..."
cat > /workspace/config/docker-compose.override.yml << 'EOF'
# Override file for local development
# Copy this to docker-compose.override.yml and modify as needed
version: '3.8'
services:
  devcontainer:
    environment:
      - DEBUG=*
      - LOG_LEVEL=debug
    volumes:
      - ./local-data:/workspace/data
EOF

echo "✅ Enhanced setup complete!"
echo ""
echo "🎉 Your development environment is ready with:"
echo "   🐳 Docker in Docker with BuildKit"
echo "   📦 Redis for caching and sessions"
echo "   🐘 PostgreSQL for database development"
echo "   🗄️  Local Docker registry"
echo "   🛠️  Development tools and aliases"
echo ""
echo "💡 Run '/workspace/scripts/health-check.sh' to verify all services"
echo "💡 Use 'dc up' to start additional services"
echo "💡 Access services at:"
echo "   - Main app: http://localhost:3000"
echo "   - Registry: http://localhost:5000"
echo "   - Redis: localhost:6379"
echo "   - PostgreSQL: localhost:5432"
