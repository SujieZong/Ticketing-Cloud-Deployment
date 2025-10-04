#!/usr/bin/env bash
set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/scripts/common.sh"
LOG_PREFIX="COMPOSE-DOWN"

log_step "=== Stopping Services ==="
docker compose down
log_success "All services stopped!"