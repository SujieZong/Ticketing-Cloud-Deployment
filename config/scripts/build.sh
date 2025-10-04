#!/usr/bin/env bash
set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"
LOG_PREFIX="BUILD"

ROOT="$(get_project_root)"

# Main build function
build_services() {
    log_step "=== Building Services ==="
    
    # Validate prerequisites
    command -v mvn >/dev/null || { log_failed "Maven not found"; exit 1; }
    command -v docker >/dev/null || { log_failed "Docker not found"; exit 1; }
    
    # Clean old containers quietly (but keep images for cache)
    log_info "Cleaning up old containers..."
    docker rm -f dev-redis dev-rabbitmq dev-mysql \
               ticketing-platform rabbit-consumer query-service purchase-service 2>/dev/null || true
    
    # Clean dangling images to save space
    log_info "Cleaning dangling Docker images..."
    docker image prune -f >/dev/null 2>&1 || true
    
    # Maven build
    cd "$ROOT"
    log_step "Building with Maven..."
    log_info "Compiling all microservices..."
    mvn clean package -DskipTests
    
    log_success "Build completed successfully!"
}

# Execute if run directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_services "$@"