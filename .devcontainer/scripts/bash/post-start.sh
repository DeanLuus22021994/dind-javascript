#!/bin/bash
# shellcheck disable=SC1091
# Post-start configuration for devcontainer
# Updated to use modular utilities

set -euo pipefail

# Source our modular utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core-utils.sh"
source "$SCRIPT_DIR/docker-utils.sh"
source "$SCRIPT_DIR/service-utils.sh"

log_info "Running post-start configuration..."

# Wait for all services to be healthy
log_info "Waiting for services to be healthy..."
if ! check_all_services; then
    log_error "Some services failed to start properly"
    exit 1
fi
timeout 30 sh -c 'until redis-cli -h localhost ping > /dev/null 2>&1; do sleep 2; done'
echo "✅ Redis is accessible"

# Test PostgreSQL connectivity
echo "🐘 Testing PostgreSQL connectivity..."
timeout 30 sh -c 'until pg_isready -h localhost -U devuser > /dev/null 2>&1; do sleep 2; done'
echo "✅ PostgreSQL is accessible"

# Set up git safe directory
echo "🔧 Configuring Git..."
git config --global --add safe.directory /workspace
git config --global init.defaultBranch main
git config --global pull.rebase false

# Warm up the cache by pulling common base images in background
echo "🔥 Warming up Docker image cache..."
{
  docker pull node:18-alpine &
  docker pull node:20-alpine &
  docker pull nginx:alpine &
  docker pull redis:7-alpine &
  docker pull postgres:15-alpine &
  docker pull alpine:latest &
  wait
  echo "✅ Base images cached"
} &

# Install project dependencies if package.json exists
if [ -f "/workspace/package.json" ]; then
  echo "📦 Installing project dependencies..."
  cd /workspace || exit 1
  npm install --cache /cache/npm
  echo "✅ Dependencies installed"
fi

# Create development database if it doesn't exist
echo "🗄️  Setting up development database..."
PGPASSWORD=devpass psql -h localhost -U devuser -d devdb -c "
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(255) PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    data JSONB,
    expires_at TIMESTAMP
  );

  -- Insert sample data if empty
  INSERT INTO users (username, email)
  SELECT 'testuser', 'test@example.com'
  WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'testuser');
" 2>/dev/null || echo "⚠️  Database setup skipped (may not be ready yet)"

# Set up Redis with some initial data
echo "📊 Setting up Redis with initial data..."
redis-cli -h localhost FLUSHDB > /dev/null 2>&1 || echo "⚠️  Redis setup skipped"
redis-cli -h localhost SET "app:version" "1.0.0" > /dev/null 2>&1 || true
redis-cli -h localhost SET "app:status" "ready" > /dev/null 2>&1 || true

# Create helpful shortcuts - commented out for non-interactive use
echo "🔗 Skipping workspace shortcuts for non-interactive use..."
cat > /workspace/.devcontainer-aliases << 'EOF'
# Development shortcuts - commented out for non-interactive use
# alias dc='docker-compose'
# alias dcu='docker-compose up -d'
# alias dcd='docker-compose down'
# alias dcr='docker-compose restart'
# alias dcl='docker-compose logs -f'

# Docker shortcuts - commented out for non-interactive use
# alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
# alias di='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'
# alias dv='docker volume ls'
# alias dn='docker network ls'

# Service connections - commented out for non-interactive use
# alias redis-cli='redis-cli -h localhost'
# alias psql-dev='PGPASSWORD=devpass psql -h localhost -U devuser -d devdb'

# Health checks - commented out for non-interactive use
# alias health='bash /workspace/.devcontainer/validate.sh'

# Development helpers - commented out for non-interactive use
# alias logs-app='tail -f /workspace/logs/combined.log'
# alias logs-error='tail -f /workspace/logs/error.log'
# alias test-watch='npm run test:watch'
# alias build-local='docker buildx bake --load'
# alias push-local='docker buildx bake --set *.output=type=registry,registry.insecure=true'
EOF

# Skip sourcing aliases for non-interactive use
echo "ℹ️  Aliases disabled for non-interactive use. Use full commands in scripts."

# Create a development status dashboard
echo "📊 Creating development dashboard..."
cat > /workspace/dev-status.sh << 'EOF'
#!/bin/bash
clear
echo "🚀 Development Environment Status"
echo "=================================="
echo ""

# Docker status
echo "🐳 Docker:"
docker version --format '  Version: {{.Server.Version}}'
echo "  BuildKit: $(docker buildx ls | grep container | awk '{print $2}')"
echo ""

# Services status
echo "🏃 Services:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}" | tail -n +2 | while read -r line; do
  echo "  $line"
done
echo ""

# Resource usage
echo "💾 Resources:"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "  Disk: $(df -h /workspace | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo ""

# Development info
echo "💻 Development:"
if [ -f "/workspace/package.json" ]; then
  echo "  Node: $(node --version)"
  echo "  NPM: $(npm --version)"
  if [ -f "/workspace/node_modules/.package-lock.json" ]; then
    echo "  Dependencies: ✅ Installed"
  else
    echo "  Dependencies: ❌ Not installed"
  fi
fi
echo ""

# Service endpoints
echo "🌐 Service Endpoints:"
echo "  Main App: http://localhost:3000"
echo "  Registry: http://localhost:5000"
echo "  Redis: localhost:6379"
echo "  PostgreSQL: localhost:5432"
echo ""

echo "💡 Quick commands:"
echo "  health      - Run health checks"
echo "  dc up       - Start all services"
echo "  dc logs     - View service logs"
echo "  npm test    - Run tests"
echo "  npm start   - Start application"
EOF

chmod +x /workspace/dev-status.sh

# Run initial health check
if [ -f "/workspace/.devcontainer/validate.sh" ]; then
  echo "🏥 Running initial health check..."
  timeout 30 bash /workspace/.devcontainer/validate.sh || echo "⚠️  Some health checks failed (services may still be starting)"
fi

echo ""
echo "✅ Post-start configuration complete!"
echo ""
echo "🎉 Your environment is ready! Quick start:"
echo "   📊 ./dev-status.sh      - View environment status"
echo "   🏥 health               - Run health checks"
echo "   🚀 npm start            - Start the application"
echo "   🧪 npm test             - Run tests"
echo "   📦 dc up                - Start additional services"
echo ""
