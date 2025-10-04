#!/usr/bin/env bash
set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/scripts/common.sh"
LOG_PREFIX="COMPOSE-UP"

# Load environment configuration
load_environment_config() {
    local env_file="$SCRIPT_DIR/config/environment/.env"
    
    if [[ -f "$env_file" ]]; then
        log_info "Loading environment: config/environment/.env"
        set -a; source "$env_file"; set +a
        log_success "Environment loaded: ${SPRING_PROFILES_ACTIVE:-docker}"
        log_info "Database: ${SPRING_DATASOURCE_URL:-default}"
        log_info "Redis: ${SPRING_DATA_REDIS_HOST:-redis}:${SPRING_DATA_REDIS_PORT:-6379}"
    else
        log_warn "Environment file not found, using defaults"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
CQRS Ticketing Platform - Docker Deployment

Usage: ./composeUp.sh [OPTIONS]

OPTIONS:
  --docker             Switch to Docker local environment
  --aws                Switch to AWS cloud environment  
  --help               Show this help

EXAMPLES:
  ./composeUp.sh                        # Use current environment
  ./composeUp.sh --docker               # Switch to Docker then deploy
  ./composeUp.sh --aws                  # Switch to AWS then deploy

SERVICES:
  - PurchaseService (8080) - Redis + RabbitMQ
  - QueryService (8081) - MySQL read access
  - RabbitConsumer - RabbitMQ + MySQL write

EOF
}

# Parse arguments
SWITCH_ENV=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --docker) SWITCH_ENV="local"; shift ;;
        --aws) SWITCH_ENV="aws"; shift ;;
        --help) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Environment setup
log_step "=== Environment Setup ==="
[[ -n "$SWITCH_ENV" ]] && {
    log_info "Switching to $SWITCH_ENV environment..."
    bash "$SCRIPT_DIR/config/environment/switch-env.sh" "$SWITCH_ENV"
}
load_environment_config

# Build phase
log_step "=== Build Phase ==="
bash "$SCRIPT_DIR/config/scripts/build.sh"

# Deploy phase
log_step "=== Deploy Phase ==="
log_info "Building Docker images with cache optimization..."
docker compose build --parallel
log_info "Starting Docker services..."
docker compose up -d
log_success "Docker services started"

# Database setup
log_step "=== Database Setup ==="
bash "$SCRIPT_DIR/config/scripts/setup-mysql.sh"

# Success
log_step "=== Deployment Complete ==="
log_success "CQRS Ticketing Platform is running!"
echo
log_info "Service URLs:"
log_info "  • PurchaseService: http://localhost:8080"
log_info "  • QueryService: http://localhost:8081"
log_info "  • RabbitMQ Admin: http://localhost:15672 (guest/guest)"
log_info "  • MySQL: localhost:3306 (${SPRING_DATASOURCE_USERNAME:-root})"
log_info "  • Redis: localhost:6379"