#!/usr/bin/env bash
set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/config/scripts/common.sh"
LOG_PREFIX="ENV"

# Environment files
ENV_DIR="$SCRIPT_DIR"
ENV_FILE="$ENV_DIR/.env"

# Simple environment switching using predefined environment files
switch_environment() {
    local env="$1"
    local source_file=""
    
    # Validate environment and set source file
    case "$env" in
        "local"|"docker")
            source_file="$ENV_DIR/.env.docker"
            env="local"
            ;;
        "aws")
            source_file="$ENV_DIR/.env.aws"
            ;;
        *)
            log_failed "Invalid environment. Use: local (or docker), aws"
            exit 1
            ;;
    esac
    
    # Check if source environment file exists
    if [[ ! -f "$source_file" ]]; then
        log_failed "Environment file not found: $source_file"
        exit 1
    fi
    
    log_step "Switching to $env environment..."
    
    # Backup current .env if it exists
    [[ -f "$ENV_FILE" ]] && cp "$ENV_FILE" "$ENV_FILE.backup"
    
    # Copy the specific environment file to .env
    cp "$source_file" "$ENV_FILE"
    
    # Show success message with environment-specific info
    case "$env" in
        "local")
            log_success "Switched to LOCAL environment (Docker)"
            log_info "✓ Using Docker containers:"
            log_info "  • MySQL: mysql:3306 (root/root)"
            log_info "  • Redis: redis:6379"
            log_info "  • RabbitMQ: rabbitmq:5672 (guest/guest)"
            ;;
        "aws")
            log_success "Switched to AWS environment"
            log_warning "⚠ AWS services required:"
            log_warning "  • RDS MySQL"
            log_warning "  • ElastiCache Redis"
            log_warning "  • Amazon MQ (RabbitMQ)"
            log_warning "  • Update credentials in .env.aws before deployment"
            ;;
    esac
    
    log_info "Active environment: $env"
    log_info "Configuration loaded from: $(basename "$source_file")"
}

# Show current environment
show_current_env() {
    if [[ -f "$ENV_FILE" ]]; then
        local current_env
        current_env=$(grep "^DEPLOYMENT_ENV=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
        local profile
        profile=$(grep "^SPRING_PROFILES_ACTIVE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
        
        echo "Current environment: $current_env (profile: $profile)"
    else
        echo "No environment file found (.env)"
    fi
}

# Show usage
show_usage() {
    echo "Environment Switcher - CQRS Ticketing Platform"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  local (or docker)  Switch to Docker local environment"
    echo "  aws               Switch to AWS cloud environment"
    echo "  status            Show current environment"
    echo
    echo "Examples:"
    echo "  $0 local          # Switch to Docker containers"
    echo "  $0 aws            # Switch to AWS services"
    echo "  $0 status         # Show current environment"
    echo
    echo "Environment Files:"
    echo "  .env.docker       Docker local configuration"
    echo "  .env.aws          AWS cloud configuration"
    echo "  .env              Active configuration (auto-generated)"
}

# Main
case "${1:-}" in
    "local"|"docker")
        switch_environment "local"
        ;;
    "aws")
        switch_environment "aws"
        ;;
    "status")
        show_current_env
        ;;
    "")
        show_usage
        exit 1
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac