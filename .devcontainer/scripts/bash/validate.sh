#!/bin/bash
# DevContainer validation script
# Validates the health and configuration of all devcontainer services

# Source utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=./core-utils.sh
source "$SCRIPT_DIR/core-utils.sh"
# shellcheck source=./docker-utils.sh
source "$SCRIPT_DIR/docker-utils.sh"
# shellcheck source=./service-utils.sh
source "$SCRIPT_DIR/service-utils.sh"

# Configuration
REQUIRED_TOOLS=("docker" "docker-compose" "node" "npm" "git")
REQUIRED_SERVICES=("redis" "postgres" "registry" "buildkit")

# Function to validate tools
validate_tools() {
    log_info "Validating required tools..."

    local all_tools_ok=true

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if command_exists "$tool"; then
            local version=""
            case "$tool" in
                "docker")
                    version=$(docker --version | cut -d' ' -f3 | tr -d ',')
                    ;;
                "docker-compose")
                    version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
                    ;;
                "node")
                    version=$(node --version)
                    ;;
                "npm")
                    version=$(npm --version)
                    ;;
                "git")
                    version=$(git --version | cut -d' ' -f3)
                    ;;
            esac
            log_success "$tool is available (version: $version)"
        else
            log_error "$tool is not installed or not in PATH"
            all_tools_ok=false
        fi
    done

    if [[ "$all_tools_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate Docker setup
validate_docker_setup() {
    log_info "Validating Docker setup..."

    if ! check_docker_system; then
        return 1
    fi

    # Check if Docker daemon is accessible
    if ! docker info >/dev/null 2>&1; then
        log_error "Cannot connect to Docker daemon"
        return 1
    fi

    # Check BuildKit
    if docker buildx ls >/dev/null 2>&1; then
        log_success "BuildKit is available"
    else
        log_warn "BuildKit may not be properly configured"
    fi

    # Check Docker Compose
    if ! check_docker_compose; then
        return 1
    fi

    return 0
}

# Function to validate network configuration
validate_network() {
    log_info "Validating network configuration..."

    local network_name="devcontainer-network"

    if docker network ls | grep -q "$network_name"; then
        log_success "Network $network_name exists"

        # Check network configuration
        local subnet
        subnet=$(docker network inspect "$network_name" | jq -r '.[0].IPAM.Config[0].Subnet')
        log_info "Network subnet: $subnet"
    else
        log_warn "Network $network_name does not exist (will be created on startup)"
    fi

    return 0
}

# Function to validate volumes
validate_volumes() {
    log_info "Validating volumes..."

    local volumes=(
        "dind-var-lib-docker"
        "dind-buildkit-cache"
        "dind-docker-cache"
        "dind-npm-cache"
        "dind-yarn-cache"
        "dind-node-modules"
        "dind-redis-data"
        "dind-postgres-data"
        "dind-registry-data"
    )

    # Check volumes exist
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_success "Volume $volume exists"
        else
            log_warn "Volume $volume does not exist (will be created on startup)"
        fi
    done

    return 0
}

# Function to validate service health
validate_services() {
    log_info "Validating service health..."

    local services_running=false

    # Check if any containers are running
    for service in "${REQUIRED_SERVICES[@]}"; do
        local container="${SERVICE_CONTAINERS[$service]}"
        if docker ps | grep -q "$container"; then
            services_running=true
            break
        fi
    done

    if [[ "$services_running" == "false" ]]; then
        log_warn "No services are currently running. Run 'docker-compose up -d' to start services."
        return 0
    fi

    # If services are running, check their health
    check_all_services
}

# Function to validate configuration files
validate_configuration() {
    log_info "Validating configuration files..."

    local config_files=(
        "../config/performance.env"
        "../devcontainer.json"
        "../docker/compose/docker-compose.main.yml"
        "../docker/compose/docker-compose.services.yml"
    )

    local all_configs_ok=true

    for config_file in "${config_files[@]}"; do
        local full_path="$SCRIPT_DIR/$config_file"
        if [[ -f "$full_path" ]]; then
            log_success "Configuration file exists: $config_file"
        else
            log_error "Configuration file missing: $config_file"
            all_configs_ok=false
        fi
    done

    if [[ "$all_configs_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate port availability
validate_ports() {
    log_info "Validating port availability..."

    local ports=("3000" "4000" "5432" "6379" "5001" "8080" "9229")

    for port in "${ports[@]}"; do
        if nc -z localhost "$port" 2>/dev/null; then
            log_info "Port $port is in use (service may be running)"
        else
            log_info "Port $port is available"
        fi
    done

    return 0
}

# Function to validate workspace structure
validate_workspace() {
    log_info "Validating workspace structure..."

    local workspace_root="$SCRIPT_DIR/../../.."
    local required_dirs=(
        "src"
        "logs"
        "__tests__"
        ".devcontainer/docker/files"
        ".devcontainer/docker/compose"
        ".devcontainer/scripts/bash"
        ".devcontainer/config"
    )

    local required_files=(
        "package.json"
        "README.md"
        ".devcontainer/devcontainer.json"
    )

    local structure_ok=true

    # Check directories
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$workspace_root/$dir" ]]; then
            log_success "Directory exists: $dir"
        else
            log_error "Directory missing: $dir"
            structure_ok=false
        fi
    done

    # Check files
    for file in "${required_files[@]}"; do
        if [[ -f "$workspace_root/$file" ]]; then
            log_success "File exists: $file"
        else
            log_error "File missing: $file"
            structure_ok=false
        fi
    done

    if [[ "$structure_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to run comprehensive validation
run_validation() {
    local validation_type="${1:-all}"
    local exit_code=0

    log_info "Starting DevContainer validation..."
    log_info "Validation type: $validation_type"
    echo "========================================"

    case "$validation_type" in
        "tools")
            validate_tools || exit_code=1
            ;;
        "docker")
            validate_docker_setup || exit_code=1
            ;;
        "network")
            validate_network || exit_code=1
            ;;
        "volumes")
            validate_volumes || exit_code=1
            ;;
        "services")
            validate_services || exit_code=1
            ;;
        "config")
            validate_configuration || exit_code=1
            ;;
        "ports")
            validate_ports || exit_code=1
            ;;
        "workspace")
            validate_workspace || exit_code=1
            ;;
        "all"|*)
            validate_workspace || exit_code=1
            validate_tools || exit_code=1
            validate_configuration || exit_code=1
            validate_docker_setup || exit_code=1
            validate_network || exit_code=1
            validate_volumes || exit_code=1
            validate_ports || exit_code=1
            validate_services || exit_code=1
            ;;
    esac

    echo "========================================"

    if [[ $exit_code -eq 0 ]]; then
        log_success "DevContainer validation completed successfully"
    else
        log_error "DevContainer validation failed with issues"
    fi

    return $exit_code
}

# Main execution
main() {
    local validation_type="${1:-all}"

    # Load environment if available
    local env_file="$SCRIPT_DIR/../config/performance.env"
    load_env_file "$env_file"

    # Run validation
    run_validation "$validation_type"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
