#!/bin/bash
# Service management utilities for devcontainer
# Provides functions to manage and monitor all services

# Source core utilities
# shellcheck disable=SC1091
source "$(dirname "$0")/core-utils.sh"
# shellcheck disable=SC1091
source "$(dirname "$0")/docker-utils.sh"

# Service configuration
declare -A SERVICES=(
    ["redis"]="6379"
    ["postgres"]="5432"
    ["registry"]="5001"
    ["buildkit"]="1234"
)

declare -A SERVICE_CONTAINERS=(
    ["redis"]="dind-redis"
    ["postgres"]="dind-postgres"
    ["registry"]="dind-registry"
    ["buildkit"]="dind-buildkit"
)

declare -A SERVICE_HEALTH_COMMANDS=(
    ["redis"]="redis-cli -h localhost ping"
    ["postgres"]="pg_isready -h localhost -U devuser -d devdb"
    ["registry"]="curl -sf http://localhost:5001/v2/"
    ["buildkit"]="docker buildx ls | grep -q container"
)

# Function to check if all services are healthy
check_all_services() {
    log_info "Checking all services..."

    local all_healthy=true

    for service in "${!SERVICES[@]}"; do
        if check_single_service "$service"; then
            log_success "$service is healthy"
        else
            log_error "$service is not healthy"
            all_healthy=false
        fi
    done

    if [[ "$all_healthy" == "true" ]]; then
        log_success "All services are healthy"
        return 0
    else
        log_error "Some services are not healthy"
        return 1
    fi
}

# Function to check a single service
check_single_service() {
    local service="$1"
    local port="${SERVICES[$service]}"
    local container="${SERVICE_CONTAINERS[$service]}"
    local health_command="${SERVICE_HEALTH_COMMANDS[$service]}"

    # Check if container is running
    if ! docker ps | grep -q "$container"; then
        log_error "Container $container is not running"
        return 1
    fi

    # Check port connectivity
    if ! check_service "$service" "$port"; then
        return 1
    fi

    # Run service-specific health check
    if ! eval "$health_command" >/dev/null 2>&1; then
        log_error "$service health check failed"
        return 1
    fi

    return 0
}

# Function to start all services
start_all_services() {
    local compose_file="${1:-docker-compose.main.yml}"
    local services_file="${2:-docker-compose.services.yml}"

    log_info "Starting all services..."

    # Start services first
    log_info "Starting infrastructure services..."
    docker-compose -f "$services_file" up -d || {
        log_error "Failed to start infrastructure services"
        return 1
    }

    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    for service in "${!SERVICES[@]}"; do
        wait_for_service "$service" "${SERVICE_HEALTH_COMMANDS[$service]}" 60 5
    done

    # Start main devcontainer
    log_info "Starting main devcontainer..."
    docker-compose -f "$compose_file" up -d || {
        log_error "Failed to start main devcontainer"
        return 1
    }

    log_success "All services started successfully"
}

# Function to stop all services
stop_all_services() {
    local compose_file="${1:-docker-compose.main.yml}"
    local services_file="${2:-docker-compose.services.yml}"

    log_info "Stopping all services..."

    # Stop main devcontainer first
    docker-compose -f "$compose_file" down || log_warn "Failed to stop main devcontainer"

    # Stop infrastructure services
    docker-compose -f "$services_file" down || log_warn "Failed to stop infrastructure services"

    log_success "All services stopped"
}

# Function to restart all services
restart_all_services() {
    local compose_file="${1:-docker-compose.main.yml}"
    local services_file="${2:-docker-compose.services.yml}"

    log_info "Restarting all services..."

    stop_all_services "$compose_file" "$services_file"
    sleep 5
    start_all_services "$compose_file" "$services_file"

    log_success "All services restarted"
}

# Function to get service status
get_service_status() {
    local service="${1:-all}"

    if [[ "$service" == "all" ]]; then
        log_info "Service Status Report:"
        echo "======================================"

        for svc in "${!SERVICES[@]}"; do
            local container="${SERVICE_CONTAINERS[$svc]}"
            local port="${SERVICES[$svc]}"

            printf "%-12s | " "$svc"

            if docker ps | grep -q "$container"; then
                if check_single_service "$svc"; then
                    printf "✅ HEALTHY\n"
                else
                    printf "⚠️  UNHEALTHY\n"
                fi
            else
                printf "❌ STOPPED\n"
            fi
        done

        echo "======================================"
    else
        if [[ -n "${SERVICES[$service]:-}" ]]; then
            check_single_service "$service"
        else
            log_error "Unknown service: $service"
            return 1
        fi
    fi
}

# Function to show service logs
show_service_logs() {
    local service="$1"
    local lines="${2:-50}"
    local follow="${3:-false}"

    if [[ -z "${SERVICE_CONTAINERS[$service]:-}" ]]; then
        log_error "Unknown service: $service"
        return 1
    fi

    local container="${SERVICE_CONTAINERS[$service]}"
    get_container_logs "$container" "$lines" "$follow"
}

# Function to execute command in service container
exec_in_service() {
    local service="$1"
    local command="$2"
    local interactive="${3:-false}"

    if [[ -z "${SERVICE_CONTAINERS[$service]:-}" ]]; then
        log_error "Unknown service: $service"
        return 1
    fi

    local container="${SERVICE_CONTAINERS[$service]}"
    exec_in_container "$container" "$command" "$interactive"
}

# Function to reset service data
reset_service_data() {
    local service="$1"
    local confirm="${2:-false}"

    if [[ "$confirm" != "true" ]]; then
        log_warn "This will delete all data for $service. Use 'reset_service_data $service true' to confirm."
        return 1
    fi

    log_info "Resetting data for service: $service"

    local container="${SERVICE_CONTAINERS[$service]}"

    # Stop the service
    docker stop "$container" 2>/dev/null || true

    # Remove service-specific volumes/data
    case "$service" in
        "redis")
            manage_volume remove "dind-redis-data" || true
            manage_volume create "dind-redis-data"
            ;;
        "postgres")
            manage_volume remove "dind-postgres-data" || true
            manage_volume create "dind-postgres-data"
            ;;
        "registry")
            manage_volume remove "dind-registry-data" || true
            manage_volume create "dind-registry-data"
            ;;
        "buildkit")
            manage_volume remove "dind-buildkit-cache" || true
            manage_volume create "dind-buildkit-cache"
            ;;
        *)
            log_error "Don't know how to reset data for service: $service"
            return 1
            ;;
    esac

    log_success "Data reset for service: $service"
}

# Function to backup service data
backup_service_data() {
    local service="$1"
    local backup_path="${2:-/tmp}"

    log_info "Backing up data for service: $service"

    case "$service" in
        "redis")
            manage_volume backup "dind-redis-data" "$backup_path/redis_backup_$(date +%Y%m%d_%H%M%S).tar"
            ;;
        "postgres")
            manage_volume backup "dind-postgres-data" "$backup_path/postgres_backup_$(date +%Y%m%d_%H%M%S).tar"
            ;;
        "registry")
            manage_volume backup "dind-registry-data" "$backup_path/registry_backup_$(date +%Y%m%d_%H%M%S).tar"
            ;;
        "buildkit")
            manage_volume backup "dind-buildkit-cache" "$backup_path/buildkit_backup_$(date +%Y%m%d_%H%M%S).tar"
            ;;
        *)
            log_error "Don't know how to backup data for service: $service"
            return 1
            ;;
    esac

    log_success "Data backed up for service: $service"
}

# Function to monitor services continuously
monitor_services() {
    local interval="${1:-10}"

    log_info "Starting service monitor (checking every ${interval}s, Ctrl+C to stop)..."

    while true; do
        clear
        echo "DevContainer Service Monitor - $(date)"
        echo "========================================"
        get_service_status all
        echo ""
        echo "Press Ctrl+C to stop monitoring"
        sleep "$interval"
    done
}

# Export functions
export -f check_all_services check_single_service start_all_services stop_all_services
export -f restart_all_services get_service_status show_service_logs exec_in_service
export -f reset_service_data backup_service_data monitor_services
