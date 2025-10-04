#!/usr/bin/env bash
set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"
LOG_PREFIX="MYSQL"

# Load environment configuration
ROOT="$(get_project_root)"
ENV_FILE="$ROOT/config/environment/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# MySQL configuration
MYSQL_CONTAINER="mysql-ticketing"
MYSQL_USER="${SPRING_DATASOURCE_USERNAME:-root}"
MYSQL_PASSWORD="${SPRING_DATASOURCE_PASSWORD:-root}"
DATABASE_NAME="ticket_platform"
SCHEMA_FILE="$ROOT/RabbitCombinedConsumer/src/main/resources/schema.sql"

# Execute MySQL commands
mysql_exec() {
    docker exec -i "$MYSQL_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$@" 2>/dev/null
}

# Wait for MySQL to be ready
wait_for_mysql() {
    log_info "Waiting for MySQL to be ready..."
    local attempts=15
    
    for ((i=1; i<=attempts; i++)); do
        if mysql_exec -e "SELECT 1;" >/dev/null 2>&1; then
            log_success "MySQL is ready!"
            return 0
        fi
        sleep 2
    done
    
    log_failed "MySQL failed to start after $attempts attempts"
    return 1
}

# Create database if not exists
create_database() {
    log_info "Setting up database '$DATABASE_NAME'..."
    
    if mysql_exec -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${DATABASE_NAME}';" | grep -q "${DATABASE_NAME}"; then
        log_info "Database exists, skipping creation"
    else
        mysql_exec -e "CREATE DATABASE ${DATABASE_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        log_success "Database created"
    fi
}

# Create tables from schema
create_tables() {
    log_info "Setting up tables..."
    
    [[ ! -f "$SCHEMA_FILE" ]] && { log_failed "Schema file not found: $SCHEMA_FILE"; return 1; }
    
    # Check if tables exist
    if mysql_exec "$DATABASE_NAME" -e "SHOW TABLES LIKE 'venue';" | grep -q venue; then
        log_info "Tables exist, skipping creation"
        return 0
    fi
    
    # Create tables
    if docker exec -i "$MYSQL_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$DATABASE_NAME" < "$SCHEMA_FILE" 2>/dev/null; then
        log_success "Tables created"
    else
        log_failed "Failed to create tables"
        return 1
    fi
}

# Verify tables
verify_tables() {
    log_info "Verifying tables..."
    local tables=("venue" "zone" "event" "ticket")
    local failed=0
    
    for table in "${tables[@]}"; do
        if mysql_exec "${DATABASE_NAME}" -e "DESCRIBE $table;" >/dev/null 2>&1; then
            log_success "Table '$table' ✓"
        else
            log_failed "Table '$table' ✗"
            ((failed++))
        fi
    done
    
    [[ $failed -gt 0 ]] && { log_failed "$failed table(s) failed verification"; return 1; }
    log_success "All tables verified!"
}

# Main setup
setup_mysql() {
    log_step "=== Setting up MySQL ==="
    
    # Prerequisites
    [[ ! -f "$SCHEMA_FILE" ]] && { log_failed "Schema file not found"; exit 1; }
    command -v mysql >/dev/null || { log_failed "MySQL client not found"; exit 1; }
    
    wait_for_mysql || exit 1
    create_database
    create_tables
    verify_tables || exit 1
    
    log_success "MySQL setup completed!"
}

# Execute if run directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_mysql "$@"