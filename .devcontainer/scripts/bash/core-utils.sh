#!/bin/bash
# Core utilities for devcontainer scripts
# This file provides reusable functions for all devcontainer scripts

set -euo pipefail

# Color codes for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Emoji shortcuts for better UX
export SUCCESS="✅"
export ERROR="❌"
export WARNING="⚠️"
export INFO="ℹ️"
export ROCKET="🚀"
export GEAR="⚙️"
export PACKAGE="📦"
export DATABASE="🗄️"
export NETWORK="🌐"
export DOCKER="🐳"
export BUILD="🏗️"
export CLOCK="⏰"
export LOCK="🔒"

# Logging levels
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3

# Default log level
export CURRENT_LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Function to print colored output with timestamp
print_status() {
    local color="$1"
    local icon="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}[${timestamp}] ${icon} ${message}${NC}"
}

# Logging functions
log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && print_status "$CYAN" "$INFO" "DEBUG: $1"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && print_status "$BLUE" "$INFO" "$1"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && print_status "$YELLOW" "$WARNING" "$1"
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && print_status "$RED" "$ERROR" "$1"
}

log_success() {
    print_status "$GREEN" "$SUCCESS" "$1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if service is running on a specific port
check_service() {
    local service_name="$1"
    local port="$2"
    local host="${3:-localhost}"
    local timeout="${4:-30}"

    log_info "Checking ${service_name} on ${host}:${port}..."

    if timeout "$timeout" bash -c "until nc -z $host $port; do sleep 1; done" 2>/dev/null; then
        log_success "${service_name} is running on ${host}:${port}"
        return 0
    else
        log_error "${service_name} is not responding on ${host}:${port}"
        return 1
    fi
}

# Function to wait for service with retries
wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local max_attempts="${3:-30}"
    local sleep_time="${4:-2}"

    log_info "Waiting for ${service_name} to be ready..."

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log_success "${service_name} is ready!"
            return 0
        fi

        log_debug "Attempt $attempt/$max_attempts failed for ${service_name}, retrying in ${sleep_time}s..."
        sleep "$sleep_time"
        ((attempt++))
    done

    log_error "${service_name} failed to start after $max_attempts attempts"
    return 1
}

# Function to check if Docker is running
check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi

    local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
    log_success "Docker is running (version: $docker_version)"
    return 0
}

# Function to check if Docker Compose is available
check_docker_compose() {
    if command_exists docker-compose; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        log_success "Docker Compose is available (version: $compose_version)"
        return 0
    elif docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version --short)
        log_success "Docker Compose (plugin) is available (version: $compose_version)"
        return 0
    else
        log_error "Docker Compose is not available"
        return 1
    fi
}

# Function to create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    local permissions="${2:-755}"

    if [[ ! -d "$dir" ]]; then
        log_info "Creating directory: $dir"
        mkdir -p "$dir"
        chmod "$permissions" "$dir"
    fi
}

# Function to backup file if it exists
backup_file() {
    local file="$1"
    local backup_suffix="${2:-$(date +%Y%m%d_%H%M%S)}"

    if [[ -f "$file" ]]; then
        local backup_file="${file}.backup.${backup_suffix}"
        log_info "Backing up $file to $backup_file"
        cp "$file" "$backup_file"
    fi
}

# Function to cleanup on script exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "Script completed successfully"
    else
        log_error "Script failed with exit code: $exit_code"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Function to validate environment variables
validate_env_var() {
    local var_name="$1"
    local default_value="${2:-}"

    if [[ -z "${!var_name:-}" ]]; then
        if [[ -n "$default_value" ]]; then
            export "$var_name"="$default_value"
            log_info "Set $var_name to default value: $default_value"
        else
            log_error "Required environment variable $var_name is not set"
            return 1
        fi
    fi
}

# Function to load environment file
load_env_file() {
    local env_file="$1"

    if [[ -f "$env_file" ]]; then
        log_info "Loading environment from: $env_file"
        set -a
        source "$env_file"
        set +a
    else
        log_warn "Environment file not found: $env_file"
    fi
}

# Export all functions
export -f print_status log_debug log_info log_warn log_error log_success
export -f command_exists check_service wait_for_service check_docker check_docker_compose
export -f ensure_directory backup_file cleanup validate_env_var load_env_file
