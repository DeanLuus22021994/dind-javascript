#!/bin/bash
# Docker-specific utilities for devcontainer
# Provides Docker management and optimization functions

# Source core utilities
source "$(dirname "$0")/core-utils.sh"

# Function to check Docker system status
check_docker_system() {
    log_info "Checking Docker system status..."

    if ! check_docker; then
        return 1
    fi

    # Check Docker daemon configuration
    local daemon_config
    daemon_config=$(docker system info --format '{{json .}}' | jq -r '.ServerVersion')
    log_info "Docker daemon version: $daemon_config"

    # Check available space
    local disk_usage
    disk_usage=$(docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}")
    log_info "Docker disk usage:\n$disk_usage"

    # Check BuildKit status
    if docker buildx ls >/dev/null 2>&1; then
        log_success "BuildKit is available"
    else
        log_warn "BuildKit is not configured"
    fi

    return 0
}

# Function to setup BuildKit
setup_buildkit() {
    log_info "Setting up BuildKit..."

    # Create buildkit builder if it doesn't exist
    if ! docker buildx ls | grep -q "container"; then
        log_info "Creating BuildKit container builder..."
        docker buildx create --name container --driver docker-container --use --bootstrap || {
            log_error "Failed to create BuildKit builder"
            return 1
        }
    else
        log_info "BuildKit container builder already exists"
    fi

    # Bootstrap the builder
    log_info "Bootstrapping BuildKit..."
    docker buildx inspect --bootstrap || {
        log_error "Failed to bootstrap BuildKit"
        return 1
    }

    log_success "BuildKit is ready"
    return 0
}

# Function to manage Docker networks
manage_network() {
    local action="$1"
    local network_name="$2"
    local subnet="${3:-192.168.100.0/24}"
    local gateway="${4:-192.168.100.1}"

    case "$action" in
        "create")
            if docker network ls | grep -q "$network_name"; then
                log_info "Network $network_name already exists"
            else
                log_info "Creating network: $network_name"
                docker network create \
                    --driver bridge \
                    --subnet="$subnet" \
                    --gateway="$gateway" \
                    --opt com.docker.network.bridge.name="dind-br0" \
                    --opt com.docker.network.driver.mtu=1500 \
                    "$network_name" || {
                    log_error "Failed to create network: $network_name"
                    return 1
                }
                log_success "Network $network_name created"
            fi
            ;;
        "remove")
            if docker network ls | grep -q "$network_name"; then
                log_info "Removing network: $network_name"
                docker network rm "$network_name" || {
                    log_error "Failed to remove network: $network_name"
                    return 1
                }
                log_success "Network $network_name removed"
            else
                log_info "Network $network_name does not exist"
            fi
            ;;
        "inspect")
            if docker network ls | grep -q "$network_name"; then
                docker network inspect "$network_name"
            else
                log_error "Network $network_name does not exist"
                return 1
            fi
            ;;
        *)
            log_error "Invalid action: $action. Use create, remove, or inspect"
            return 1
            ;;
    esac
}

# Function to manage Docker volumes
manage_volume() {
    local action="$1"
    local volume_name="$2"
    local driver="${3:-local}"

    case "$action" in
        "create")
            if docker volume ls | grep -q "$volume_name"; then
                log_info "Volume $volume_name already exists"
            else
                log_info "Creating volume: $volume_name"
                docker volume create --driver="$driver" "$volume_name" || {
                    log_error "Failed to create volume: $volume_name"
                    return 1
                }
                log_success "Volume $volume_name created"
            fi
            ;;
        "remove")
            if docker volume ls | grep -q "$volume_name"; then
                log_info "Removing volume: $volume_name"
                docker volume rm "$volume_name" || {
                    log_error "Failed to remove volume: $volume_name"
                    return 1
                }
                log_success "Volume $volume_name removed"
            else
                log_info "Volume $volume_name does not exist"
            fi
            ;;
        "inspect")
            if docker volume ls | grep -q "$volume_name"; then
                docker volume inspect "$volume_name"
            else
                log_error "Volume $volume_name does not exist"
                return 1
            fi
            ;;
        "backup")
            local backup_path="${3:-/tmp/${volume_name}_backup_$(date +%Y%m%d_%H%M%S).tar}"
            log_info "Backing up volume $volume_name to $backup_path"
            docker run --rm -v "$volume_name:/data" -v "$(dirname "$backup_path"):/backup" \
                alpine tar czf "/backup/$(basename "$backup_path")" -C /data . || {
                log_error "Failed to backup volume: $volume_name"
                return 1
            }
            log_success "Volume $volume_name backed up to $backup_path"
            ;;
        *)
            log_error "Invalid action: $action. Use create, remove, inspect, or backup"
            return 1
            ;;
    esac
}

# Function to cleanup Docker system
cleanup_docker() {
    local aggressive="${1:-false}"

    log_info "Cleaning up Docker system..."

    # Remove unused containers
    log_info "Removing stopped containers..."
    docker container prune -f || log_warn "Failed to remove stopped containers"

    # Remove unused images
    log_info "Removing unused images..."
    if [[ "$aggressive" == "true" ]]; then
        docker image prune -a -f || log_warn "Failed to remove unused images"
    else
        docker image prune -f || log_warn "Failed to remove dangling images"
    fi

    # Remove unused networks
    log_info "Removing unused networks..."
    docker network prune -f || log_warn "Failed to remove unused networks"

    # Remove unused volumes (only if aggressive)
    if [[ "$aggressive" == "true" ]]; then
        log_info "Removing unused volumes..."
        docker volume prune -f || log_warn "Failed to remove unused volumes"
    fi

    # Clean build cache
    log_info "Cleaning build cache..."
    docker builder prune -f || log_warn "Failed to clean build cache"

    log_success "Docker cleanup completed"
}

# Function to check container health
check_container_health() {
    local container_name="$1"
    local timeout="${2:-60}"

    log_info "Checking health of container: $container_name"

    if ! docker ps | grep -q "$container_name"; then
        log_error "Container $container_name is not running"
        return 1
    fi

    local health_status=""
    local attempts=0
    local max_attempts=$((timeout / 5))

    while [[ $attempts -lt $max_attempts ]]; do
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")

        case "$health_status" in
            "healthy")
                log_success "Container $container_name is healthy"
                return 0
                ;;
            "unhealthy")
                log_error "Container $container_name is unhealthy"
                return 1
                ;;
            "starting")
                log_info "Container $container_name is starting (attempt $((attempts + 1))/$max_attempts)..."
                ;;
            "no-healthcheck")
                log_info "Container $container_name has no health check configured"
                return 0
                ;;
        esac

        sleep 5
        ((attempts++))
    done

    log_error "Container $container_name health check timed out"
    return 1
}

# Function to get container logs
get_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    local follow="${3:-false}"

    if ! docker ps -a | grep -q "$container_name"; then
        log_error "Container $container_name does not exist"
        return 1
    fi

    log_info "Getting logs for container: $container_name (last $lines lines)"

    if [[ "$follow" == "true" ]]; then
        docker logs -f --tail="$lines" "$container_name"
    else
        docker logs --tail="$lines" "$container_name"
    fi
}

# Function to execute command in container
exec_in_container() {
    local container_name="$1"
    local command="$2"
    local interactive="${3:-false}"

    if ! docker ps | grep -q "$container_name"; then
        log_error "Container $container_name is not running"
        return 1
    fi

    log_info "Executing command in container $container_name: $command"

    if [[ "$interactive" == "true" ]]; then
        docker exec -it "$container_name" $command
    else
        docker exec "$container_name" $command
    fi
}

# Export functions
export -f check_docker_system setup_buildkit manage_network manage_volume
export -f cleanup_docker check_container_health get_container_logs exec_in_container
