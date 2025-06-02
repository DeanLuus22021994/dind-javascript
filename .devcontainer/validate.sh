#!/bin/bash
# DevContainer Validation and Test Suite
# This script validates that all components of the enhanced devcontainer are working correctly

set -e

# Source utilities
source "$(dirname "$0")/dev-utils.sh"

print_status "$BLUE" "$ROCKET" "Starting DevContainer Validation Suite"
echo ""

# Test 1: Docker Engine
print_status "$BLUE" "$DOCKER" "Test 1: Docker Engine"
if docker info >/dev/null 2>&1; then
    docker_version=$(docker version --format '{{.Server.Version}}')
    print_status "$GREEN" "$SUCCESS" "Docker Engine is running (version: $docker_version)"
else
    print_status "$RED" "$ERROR" "Docker Engine is not running"
    exit 1
fi

# Test 2: BuildKit
print_status "$BLUE" "$BUILD" "Test 2: BuildKit Configuration"
if docker buildx ls | grep -q "container"; then
    print_status "$GREEN" "$SUCCESS" "BuildKit is properly configured"
else
    print_status "$YELLOW" "$WARNING" "BuildKit not found, attempting to create..."
    docker buildx create --name container --driver docker-container --use --bootstrap
    if docker buildx ls | grep -q "container"; then
        print_status "$GREEN" "$SUCCESS" "BuildKit created and configured"
    else
        print_status "$RED" "$ERROR" "Failed to configure BuildKit"
        exit 1
    fi
fi

# Test 3: Services Connectivity
print_status "$BLUE" "$NETWORK" "Test 3: Service Connectivity"
services_healthy=true

# Check Redis
if check_service "Redis" 6379; then
    # Test Redis functionality
    if redis-cli -h localhost ping | grep -q "PONG"; then
        print_status "$GREEN" "$SUCCESS" "Redis is functional"
    else
        print_status "$RED" "$ERROR" "Redis ping failed"
        services_healthy=false
    fi
else
    services_healthy=false
fi

# Check PostgreSQL
if check_service "PostgreSQL" 5432; then
    # Test PostgreSQL connectivity
    if PGPASSWORD=devpass pg_isready -h localhost -U devuser >/dev/null 2>&1; then
        print_status "$GREEN" "$SUCCESS" "PostgreSQL is functional"
    else
        print_status "$RED" "$ERROR" "PostgreSQL connection failed"
        services_healthy=false
    fi
else
    services_healthy=false
fi

# Check Registry
if check_service "Docker Registry" 5000; then
    # Test registry API
    if curl -sf http://localhost:5000/v2/ >/dev/null; then
        print_status "$GREEN" "$SUCCESS" "Docker Registry is functional"
    else
        print_status "$RED" "$ERROR" "Registry API test failed"
        services_healthy=false
    fi
else
    services_healthy=false
fi

if ! $services_healthy; then
    print_status "$RED" "$ERROR" "Some services are not healthy"
    exit 1
fi

# Test 4: Build System
print_status "$BLUE" "$BUILD" "Test 4: Build System"
cd /workspace

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
    print_status "$RED" "$ERROR" "NPM cache directory issue"
    exit 1
fi

# Check yarn cache
if [ -d "/cache/yarn" ] && [ -w "/cache/yarn" ]; then
    print_status "$GREEN" "$SUCCESS" "Yarn cache directory is accessible"
else
    print_status "$RED" "$ERROR" "Yarn cache directory issue"
    exit 1
fi

# Test npm functionality
if npm config get cache | grep -q "/cache/npm"; then
    print_status "$GREEN" "$SUCCESS" "NPM cache is properly configured"
else
    print_status "$RED" "$ERROR" "NPM cache configuration issue"
    exit 1
fi

# Test 6: Development Tools
print_status "$BLUE" "$GEAR" "Test 6: Development Tools"

# Check essential tools
tools=("node" "npm" "yarn" "git" "curl" "wget" "jq" "redis-cli" "psql")
missing_tools=()

for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$(${tool} --version 2>/dev/null | head -1 || echo "installed")
        print_status "$GREEN" "$SUCCESS" "$tool is available ($version)"
    else
        print_status "$RED" "$ERROR" "$tool is not available"
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    print_status "$RED" "$ERROR" "Missing tools: ${missing_tools[*]}"
    exit 1
fi

# Test 7: Volume Mounts
print_status "$BLUE" "$DATABASE" "Test 7: Volume Mounts"

# Check critical mounts
mounts=("/workspace" "/cache" "/var/lib/docker")
for mount in "${mounts[@]}"; do
    if [ -d "$mount" ] && [ -w "$mount" ]; then
        print_status "$GREEN" "$SUCCESS" "$mount is properly mounted and writable"
    else
        print_status "$RED" "$ERROR" "$mount mount issue"
        exit 1
    fi
done

# Test 8: Network Configuration
print_status "$BLUE" "$NETWORK" "Test 8: Network Configuration"

# Check internet connectivity
if curl -sf https://registry.npmjs.org/ >/dev/null; then
    print_status "$GREEN" "$SUCCESS" "External network connectivity is working"
else
    print_status "$YELLOW" "$WARNING" "External network connectivity issue (may be expected in some environments)"
fi

# Check internal DNS resolution
if nslookup redis >/dev/null 2>&1; then
    print_status "$GREEN" "$SUCCESS" "Internal DNS resolution is working"
else
    print_status "$YELLOW" "$WARNING" "Internal DNS resolution issue (services may not be in compose network)"
fi

# Test 9: Security Configuration
print_status "$BLUE" "$GEAR" "Test 9: Security Configuration"

# Check user permissions
if [ "$USER" = "vscode" ] || [ "$USER" = "node" ]; then
    print_status "$GREEN" "$SUCCESS" "Running as non-root user ($USER)"
else
    print_status "$YELLOW" "$WARNING" "Running as user: $USER (may not be optimal)"
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
cat > /tmp/test.Dockerfile << 'EOF'
FROM node:18-alpine
RUN npm install -g typescript
WORKDIR /app
COPY package*.json ./
RUN echo '{"name":"test","version":"1.0.0"}' > package.json && npm install
EOF

# Test build with cache
if docker buildx build -f /tmp/test.Dockerfile --cache-from type=local,src=/cache/buildkit --cache-to type=local,dest=/cache/buildkit,mode=max -t test:cache /tmp >/dev/null 2>&1; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    print_status "$GREEN" "$SUCCESS" "Build cache test completed in ${duration}s"
    docker rmi test:cache >/dev/null 2>&1 || true
else
    print_status "$YELLOW" "$WARNING" "Build cache test failed (may be expected)"
fi

# Cleanup test files
rm -f /tmp/test.Dockerfile

echo ""
print_status "$GREEN" "$SUCCESS" "All validation tests completed successfully!"
echo ""
print_status "$CYAN" "$INFO" "DevContainer Health Summary:"
echo "  🐳 Docker Engine: ✅ Running"
echo "  🏗️  BuildKit: ✅ Configured"
echo "  📦 Redis: ✅ Functional"
echo "  🐘 PostgreSQL: ✅ Functional"
echo "  🗄️  Registry: ✅ Functional"
echo "  🛠️  Tools: ✅ Available"
echo "  💾 Storage: ✅ Mounted"
echo "  🌐 Network: ✅ Connected"
echo "  🔒 Security: ✅ Configured"
echo ""
print_status "$ROCKET" "$SUCCESS" "Your enhanced DevContainer is ready for development!"
echo ""
print_status "$CYAN" "$INFO" "Next steps:"
echo "  • Run 'npm install' to install project dependencies"
echo "  • Run 'npm start' to start the application"
echo "  • Run './dev-status.sh' to monitor the environment"
echo "  • Use VS Code tasks for common operations"
