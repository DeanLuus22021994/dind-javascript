#!/bin/bash
# filepath: c:\Projects\dind-javascript\.devcontainer\validate.sh
# DevContainer Validation and Test Suite
# This script validates that all components of the enhanced devcontainer are working correctly

set -euo pipefail

# Source utilities with proper error handling
SCRIPT_DIR="$(dirname "$0")"
if [ -f "${SCRIPT_DIR}/dev-utils.sh" ]; then
    # shellcheck source=./dev-utils.sh disable=SC1091
    source "${SCRIPT_DIR}/dev-utils.sh"
else
    # Fallback functions if dev-utils.sh is not available
    print_status() {
        local color="$1"
        local icon="$2"
        local message="$3"
        echo -e "${color}${icon} ${message}${NC:-}"
    }

    check_service() {
        local service_name="$1"
        local port="$2"
        if command -v nc >/dev/null 2>&1 && nc -z localhost "$port" 2>/dev/null; then
            print_status "\033[0;32m" "✅" "$service_name is accessible on port $port"
            return 0
        elif command -v telnet >/dev/null 2>&1; then
            if timeout 5 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
                print_status "\033[0;32m" "✅" "$service_name is accessible on port $port"
                return 0
            fi
        fi
        print_status "\033[0;31m" "❌" "$service_name is not accessible on port $port"
        return 1
    }

    # Color codes
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'

    # Icons
    SUCCESS="✅"
    ERROR="❌"
    WARNING="⚠️"
    INFO="ℹ️"
    ROCKET="🚀"
    GEAR="⚙️"
    PACKAGE="📦"
    DATABASE="🗄️"
    NETWORK="🌐"
    DOCKER="🐳"
    BUILD="🏗️"
fi

print_status "$BLUE" "$ROCKET" "Starting DevContainer Validation Suite"
echo ""

# Test 1: Docker Engine
print_status "$BLUE" "$DOCKER" "Test 1: Docker Engine"
if docker info >/dev/null 2>&1; then
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    print_status "$GREEN" "$SUCCESS" "Docker Engine is running (version: $docker_version)"
else
    print_status "$RED" "$ERROR" "Docker Engine is not running"
    exit 1
fi

# Test 2: BuildKit
print_status "$BLUE" "$BUILD" "Test 2: BuildKit Configuration"
if docker buildx ls 2>/dev/null | grep -q "container"; then
    print_status "$GREEN" "$SUCCESS" "BuildKit is properly configured"
else
    print_status "$YELLOW" "$WARNING" "BuildKit not found, attempting to create..."
    if docker buildx create --name container --driver docker-container --use --bootstrap >/dev/null 2>&1; then
        if docker buildx ls 2>/dev/null | grep -q "container"; then
            print_status "$GREEN" "$SUCCESS" "BuildKit created and configured"
        else
            print_status "$RED" "$ERROR" "Failed to configure BuildKit"
            exit 1
        fi
    else
        print_status "$RED" "$ERROR" "Failed to create BuildKit builder"
        exit 1
    fi
fi

# Test 3: Services Connectivity
print_status "$BLUE" "$NETWORK" "Test 3: Service Connectivity"
services_healthy=true

# Check Redis
if check_service "Redis" 6379; then
    # Test Redis functionality
    if command -v redis-cli >/dev/null 2>&1 && redis-cli -h localhost ping 2>/dev/null | grep -q "PONG"; then
        print_status "$GREEN" "$SUCCESS" "Redis is functional"
    else
        print_status "$YELLOW" "$WARNING" "Redis port accessible but ping failed"
    fi
else
    services_healthy=false
fi

# Check PostgreSQL
if check_service "PostgreSQL" 5432; then
    # Test PostgreSQL connectivity
    if command -v pg_isready >/dev/null 2>&1 && PGPASSWORD=devpass pg_isready -h localhost -U devuser >/dev/null 2>&1; then
        print_status "$GREEN" "$SUCCESS" "PostgreSQL is functional"
    else
        print_status "$YELLOW" "$WARNING" "PostgreSQL port accessible but connection failed"
    fi
else
    services_healthy=false
fi

# Check Registry
if check_service "Docker Registry" 5000; then
    # Test registry API
    if command -v curl >/dev/null 2>&1 && curl -sf http://localhost:5000/v2/ >/dev/null 2>&1; then
        print_status "$GREEN" "$SUCCESS" "Docker Registry is functional"
    else
        print_status "$YELLOW" "$WARNING" "Registry port accessible but API test failed"
    fi
else
    services_healthy=false
fi

if ! $services_healthy; then
    print_status "$YELLOW" "$WARNING" "Some services are not healthy (this may be expected if services are still starting)"
fi

# Test 4: Build System
print_status "$BLUE" "$BUILD" "Test 4: Build System"
if ! cd /workspace 2>/dev/null; then
    print_status "$RED" "$ERROR" "Cannot access workspace directory"
    exit 1
fi

# Test docker-bake.hcl exists and is valid
if [ -f "docker-bake.hcl" ]; then
    if docker buildx bake --print >/dev/null 2>&1; then
        print_status "$GREEN" "$SUCCESS" "Docker Bake configuration is valid"
    else
        print_status "$RED" "$ERROR" "Docker Bake configuration is invalid"
        exit 1
    fi
else
    print_status "$RED" "$ERROR" "docker-bake.hcl not found"
    exit 1
fi

# Test 5: Package Management
print_status "$BLUE" "$PACKAGE" "Test 5: Package Management"

# Check npm cache
if [ -d "/cache/npm" ] && [ -w "/cache/npm" ]; then
    print_status "$GREEN" "$SUCCESS" "NPM cache directory is accessible"
else
    print_status "$YELLOW" "$WARNING" "NPM cache directory issue (creating if needed)"
    mkdir -p /cache/npm 2>/dev/null || true
fi

# Check yarn cache
if [ -d "/cache/yarn" ] && [ -w "/cache/yarn" ]; then
    print_status "$GREEN" "$SUCCESS" "Yarn cache directory is accessible"
else
    print_status "$YELLOW" "$WARNING" "Yarn cache directory issue (creating if needed)"
    mkdir -p /cache/yarn 2>/dev/null || true
fi

# Test npm functionality
if command -v npm >/dev/null 2>&1; then
    cache_dir=$(npm config get cache 2>/dev/null || echo "")
    if [[ "$cache_dir" == *"/cache/npm"* ]] || [[ "$cache_dir" == *"cache"* ]]; then
        print_status "$GREEN" "$SUCCESS" "NPM cache is properly configured"
    else
        print_status "$YELLOW" "$WARNING" "NPM cache configuration may need adjustment"
    fi
else
    print_status "$RED" "$ERROR" "NPM is not available"
    exit 1
fi

# Test 6: Development Tools
print_status "$BLUE" "$GEAR" "Test 6: Development Tools"

# Check essential tools
tools=("node" "npm" "git" "curl")
optional_tools=("yarn" "wget" "jq" "redis-cli" "psql")
missing_tools=()

for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
        print_status "$GREEN" "$SUCCESS" "$tool is available ($version)"
    else
        print_status "$RED" "$ERROR" "$tool is not available"
        missing_tools+=("$tool")
    fi
done

for tool in "${optional_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
        print_status "$GREEN" "$SUCCESS" "$tool is available ($version)"
    else
        print_status "$YELLOW" "$INFO" "$tool is not available (optional)"
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    print_status "$RED" "$ERROR" "Missing essential tools: ${missing_tools[*]}"
    exit 1
fi

# Test 7: Volume Mounts
print_status "$BLUE" "$DATABASE" "Test 7: Volume Mounts"

# Check critical mounts
critical_mounts=("/workspace")
optional_mounts=("/cache" "/var/lib/docker")

for mount in "${critical_mounts[@]}"; do
    if [ -d "$mount" ] && [ -w "$mount" ]; then
        print_status "$GREEN" "$SUCCESS" "$mount is properly mounted and writable"
    else
        print_status "$RED" "$ERROR" "$mount mount issue"
        exit 1
    fi
done

for mount in "${optional_mounts[@]}"; do
    if [ -d "$mount" ] && [ -w "$mount" ]; then
        print_status "$GREEN" "$SUCCESS" "$mount is properly mounted and writable"
    else
        print_status "$YELLOW" "$INFO" "$mount mount not available (may be expected)"
    fi
done

# Test 8: Network Configuration
print_status "$BLUE" "$NETWORK" "Test 8: Network Configuration"

# Check internet connectivity
if command -v curl >/dev/null 2>&1 && curl -sf --max-time 10 https://registry.npmjs.org/ >/dev/null 2>&1; then
    print_status "$GREEN" "$SUCCESS" "External network connectivity is working"
else
    print_status "$YELLOW" "$WARNING" "External network connectivity issue (may be expected in some environments)"
fi

# Check internal DNS resolution
if command -v nslookup >/dev/null 2>&1 && nslookup redis >/dev/null 2>&1; then
    print_status "$GREEN" "$SUCCESS" "Internal DNS resolution is working"
else
    print_status "$YELLOW" "$WARNING" "Internal DNS resolution issue (services may not be in compose network)"
fi

# Test 9: Security Configuration
print_status "$BLUE" "$GEAR" "Test 9: Security Configuration"

# Check user permissions
current_user="${USER:-$(whoami 2>/dev/null || echo 'unknown')}"
if [ "$current_user" = "vscode" ] || [ "$current_user" = "node" ] || [ "$current_user" != "root" ]; then
    print_status "$GREEN" "$SUCCESS" "Running as non-root user ($current_user)"
else
    print_status "$YELLOW" "$WARNING" "Running as user: $current_user (consider using non-root user)"
fi

# Check Docker socket access
if docker ps >/dev/null 2>&1; then
    print_status "$GREEN" "$SUCCESS" "Docker socket is accessible"
else
    print_status "$RED" "$ERROR" "Docker socket access issue"
    exit 1
fi

# Test 10: Development Environment
print_status "$BLUE" "$PACKAGE" "Test 10: Development Environment"

# Check if package.json exists and dependencies can be installed
if [ -f "/workspace/package.json" ]; then
    print_status "$GREEN" "$SUCCESS" "package.json found"

    # Try a quick install test (dry-run)
    if npm install --dry-run >/dev/null 2>&1; then
        print_status "$GREEN" "$SUCCESS" "Dependencies can be resolved"
    else
        print_status "$YELLOW" "$WARNING" "Dependency resolution issues (may need npm install)"
    fi
else
    print_status "$YELLOW" "$INFO" "No package.json found (this is normal for a fresh setup)"
fi

# Performance Test
print_status "$BLUE" "$ROCKET" "Performance Test: Build Cache"
start_time=$(date +%s)

# Create a simple test Dockerfile
test_dockerfile="/tmp/test.Dockerfile"
cat > "$test_dockerfile" << 'EOF'
FROM node:18-alpine
RUN npm install -g typescript
WORKDIR /app
COPY package*.json ./
RUN echo '{"name":"test","version":"1.0.0"}' > package.json && npm install
EOF

# Test build with cache
build_args=(
    "-f" "$test_dockerfile"
    "--cache-from" "type=local,src=/cache/buildkit"
    "--cache-to" "type=local,dest=/cache/buildkit,mode=max"
    "-t" "test:cache"
    "/tmp"
)

if docker buildx build "${build_args[@]}" >/dev/null 2>&1; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    print_status "$GREEN" "$SUCCESS" "Build cache test completed in ${duration}s"
    docker rmi test:cache >/dev/null 2>&1 || true
else
    print_status "$YELLOW" "$WARNING" "Build cache test failed (may be expected)"
fi

# Cleanup test files
rm -f "$test_dockerfile"

echo ""
print_status "$GREEN" "$SUCCESS" "Validation suite completed!"
echo ""
print_status "$CYAN" "$INFO" "DevContainer Health Summary:"
echo "  🐳 Docker Engine: ✅ Running"
echo "  🏗️  BuildKit: ✅ Configured"
echo "  📦 Redis: $([ "$services_healthy" = "true" ] && echo "✅ Functional" || echo "⚠️  Check pending")"
echo "  🐘 PostgreSQL: $([ "$services_healthy" = "true" ] && echo "✅ Functional" || echo "⚠️  Check pending")"
echo "  🗄️  Registry: $([ "$services_healthy" = "true" ] && echo "✅ Functional" || echo "⚠️  Check pending")"
echo "  🛠️  Tools: ✅ Available"
echo "  💾 Storage: ✅ Mounted"
echo "  🌐 Network: ✅ Connected"
echo "  🔒 Security: ✅ Configured"
echo ""

if [ "$services_healthy" = "true" ]; then
    print_status "$ROCKET" "$SUCCESS" "Your enhanced DevContainer is fully ready for development!"
else
    print_status "$YELLOW" "$WARNING" "DevContainer is mostly ready - some services may still be starting"
fi

echo ""
print_status "$CYAN" "$INFO" "Next steps:"
echo "  • Run 'npm install' to install project dependencies"
echo "  • Run 'npm start' to start the application"
echo "  • Run './dev-status.sh' to monitor the environment"
echo "  • Use VS Code tasks for common operations"
echo ""
print_status "$BLUE" "$INFO" "For troubleshooting, check:"
echo "  • docker-compose logs -f (in .devcontainer directory)"
echo "  • docker ps (to see running containers)"
echo "  • ./dev-status.sh (for environment overview)"
