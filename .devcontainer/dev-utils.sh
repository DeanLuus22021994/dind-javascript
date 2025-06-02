#!/bin/bash
# Development Environment Configuration and Utilities

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emoji shortcuts
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

# Function to print colored output
print_status() {
    local color=$1
    local emoji=$2
    local message=$3
    echo -e "${color}${emoji} ${message}${NC}"
}

# Function to check if service is running
check_service() {
    local service=$1
    local port=$2
    local host=${3:-localhost}

    if nc -z "$host" "$port" 2>/dev/null; then
        print_status "$GREEN" "$SUCCESS" "$service is running on $host:$port"
        return 0
    else
        print_status "$RED" "$ERROR" "$service is not accessible on $host:$port"
        return 1
    fi
}

# Function to wait for service
wait_for_service() {
    local service=$1
    local port=$2
    local host=${3:-localhost}
    local timeout=${4:-30}

    print_status "$YELLOW" "$GEAR" "Waiting for $service on $host:$port..."

    for _ in $(seq 1 "$timeout"); do
        if nc -z "$host" "$port" 2>/dev/null; then
            print_status "$GREEN" "$SUCCESS" "$service is ready!"
            return 0
        fi
        sleep 1
    done

    print_status "$RED" "$ERROR" "$service failed to start within ${timeout}s"
    return 1
}

# Function to check Docker health
check_docker() {
    print_status "$BLUE" "$DOCKER" "Checking Docker status..."

    if docker info >/dev/null 2>&1; then
        local version
        version=$(docker version --format '{{.Server.Version}}')
        print_status "$GREEN" "$SUCCESS" "Docker daemon is running (version: $version)"

        # Check BuildKit
        if docker buildx ls | grep -q "container"; then
            print_status "$GREEN" "$SUCCESS" "BuildKit is configured"
        else
            print_status "$YELLOW" "$WARNING" "BuildKit not configured"
        fi

        return 0
    else
        print_status "$RED" "$ERROR" "Docker daemon is not running"
        return 1
    fi
}

# Function to check all services
check_all_services() {
    print_status "$BLUE" "$GEAR" "Checking all services..."

    local services_ok=true

    # Check Docker first
    check_docker || services_ok=false

    # Check core services
    check_service "Redis" 6379 || services_ok=false
    check_service "PostgreSQL" 5432 || services_ok=false
    check_service "Docker Registry" 5000 || services_ok=false

    # Check application ports
    if check_service "Main App" 3000; then
        print_status "$GREEN" "$SUCCESS" "Application is running"
    else
        print_status "$YELLOW" "$INFO" "Application not running (this is normal if not started)"
    fi

    if $services_ok; then
        print_status "$GREEN" "$SUCCESS" "All core services are healthy!"
        return 0
    else
        print_status "$RED" "$ERROR" "Some services are not healthy"
        return 1
    fi
}

# Function to setup development database
setup_dev_database() {
    print_status "$BLUE" "$DATABASE" "Setting up development database..."

    # Wait for PostgreSQL to be ready
    wait_for_service "PostgreSQL" 5432 || return 1

    # Create sample schema and data
    PGPASSWORD=devpass psql -h localhost -U devuser -d devdb << 'EOF'
-- Create tables if they don't exist
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    published BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(255) PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    data JSONB,
    expires_at TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_published ON posts(published);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

-- Insert sample data if tables are empty
INSERT INTO users (username, email, password_hash)
SELECT 'admin', 'admin@example.com', '$2b$10$example.hash.here'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

INSERT INTO users (username, email, password_hash)
SELECT 'testuser', 'test@example.com', '$2b$10$example.hash.here'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'testuser');

INSERT INTO posts (user_id, title, content, published)
SELECT 1, 'Welcome to the Blog', 'This is a sample blog post for development.', true
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE title = 'Welcome to the Blog');

INSERT INTO posts (user_id, title, content, published)
SELECT 2, 'Test Post', 'This is another test post.', false
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE title = 'Test Post');

-- Show summary
SELECT 'Users' as table_name, count(*) as records FROM users
UNION ALL
SELECT 'Posts' as table_name, count(*) as records FROM posts
UNION ALL
SELECT 'Sessions' as table_name, count(*) as records FROM sessions;
EOF
    if print_status "$GREEN" "$SUCCESS" "Development database setup complete"; then
        return 0
    else
        print_status "$RED" "$ERROR" "Failed to setup development database"
        return 1
    fi
}

# Function to setup Redis cache
setup_redis_cache() {
    print_status "$BLUE" "$PACKAGE" "Setting up Redis cache..."

    # Wait for Redis to be ready
    wait_for_service "Redis" 6379 || return 1

    # Setup initial cache data
    redis-cli -h localhost << 'EOF'
FLUSHDB
SET app:version "1.0.0"
SET app:status "ready"
SET app:environment "development"
HSET user:1 username "admin" email "admin@example.com"
HSET user:2 username "testuser" email "test@example.com"
LPUSH recent:posts "Welcome to the Blog" "Test Post"
SET cache:health "ok"
EXPIRE cache:health 300
EOF

    if print_status "$GREEN" "$SUCCESS" "Redis cache setup complete"; then
        return 0
    else
        print_status "$RED" "$ERROR" "Failed to setup Redis cache"
        return 1
    fi
}

# Function to install project dependencies
install_dependencies() {
    if [ ! -f "/workspace/package.json" ]; then
        print_status "$YELLOW" "$WARNING" "No package.json found, skipping dependency installation"
        return 0
    fi

    print_status "$BLUE" "$PACKAGE" "Installing project dependencies..."

    cd /workspace || return

    # Choose package manager
    if [ -f "yarn.lock" ]; then
        print_status "$BLUE" "$INFO" "Using Yarn..."
        yarn install --cache-folder /cache/yarn
        result=$?
    elif [ -f "package-lock.json" ]; then
        print_status "$BLUE" "$INFO" "Using npm..."
        npm install --cache /cache/npm
        result=$?
    else
        print_status "$BLUE" "$INFO" "Using npm (no lock file found)..."
        npm install --cache /cache/npm
        result=$?
    fi

    if [ $result -eq 0 ]; then
        print_status "$GREEN" "$SUCCESS" "Dependencies installed successfully"
        return 0
    else
        print_status "$RED" "$ERROR" "Failed to install dependencies"
        return 1
    fi
}

# Function to run development setup
dev_setup() {
    print_status "$BLUE" "$ROCKET" "Running complete development setup..."

    check_all_services
    setup_dev_database
    setup_redis_cache
    install_dependencies

    print_status "$GREEN" "$SUCCESS" "Development setup complete!"
    print_status "$CYAN" "$INFO" "Run './dev-status.sh' to see environment status"
}

# Function to cleanup development environment
dev_cleanup() {
    print_status "$BLUE" "$GEAR" "Cleaning up development environment..."

    # Stop services
    docker-compose down

    # Clean Docker resources
    docker system prune -f
    docker volume prune -f

    # Clean npm cache
    npm cache clean --force 2>/dev/null || true

    # Clean yarn cache
    yarn cache clean 2>/dev/null || true

    print_status "$GREEN" "$SUCCESS" "Cleanup complete!"
}

# Function to backup development environment
dev_backup() {
    local backup_dir
    backup_dir="/workspace/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    print_status "$BLUE" "$GEAR" "Creating backup in $backup_dir..."

    # Backup PostgreSQL
    PGPASSWORD=devpass pg_dump -h localhost -U devuser devdb > "$backup_dir/postgres.sql"

    # Backup Redis
    redis-cli -h localhost --rdb "$backup_dir/redis.rdb"

    # Backup Docker volumes
    docker run --rm -v dind-var-lib-docker:/data -v "$backup_dir":/backup alpine tar czf /backup/docker-data.tar.gz -C /data .

    print_status "$GREEN" "$SUCCESS" "Backup created in $backup_dir"
}
# Export functions for use in other scripts
export -f print_status
export -f check_service
export -f wait_for_service
export -f check_docker
export -f check_all_services
export -f setup_dev_database
export -f setup_redis_cache
export -f install_dependencies
export -f dev_setup
export -f dev_cleanup
export -f dev_backup

# Color and emoji variables
export RED GREEN YELLOW BLUE PURPLE CYAN NC
export SUCCESS ERROR WARNING INFO ROCKET GEAR PACKAGE DATABASE NETWORK DOCKER BUILD
