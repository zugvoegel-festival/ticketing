#!/usr/bin/env bash
# Backup and Restore Management Script for Zugvoegel Services
# This script helps manage individual service backups and restores
#
# Features:
# - Automatic repository initialization if repository doesn't exist
# - Dynamic configuration from NixOS deployment
# - Support for multiple backup services
# - List, backup, restore, and init operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available services (injected at build time)
SERVICES=(@serviceList@)

usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list-services              List all configured backup services"
    echo "  status [service]           Show backup status for service (or all)"
    echo "  backup <service>           Run backup for specific service"
    echo "  list-snapshots <service>   List snapshots for service"
    echo "  restore <service> <snapshot-id> <target-path>  Restore service from snapshot"
    echo "  init <service>             Initialize restic repository for service"
    echo ""
    echo "Services: ${SERVICES[*]}"
    echo ""
    echo "Examples:"
    echo "  $0 status                  # Show status of all backup services"
    echo "  $0 backup pretix-db        # Backup pretix database"
    echo "  $0 list-snapshots pretix-db    # List pretix-db backup snapshots"
    echo "  $0 restore pretix-data latest /tmp/restore  # Restore pretix data"
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

validate_service() {
    local service="$1"
    if [[ ! " ${SERVICES[*]} " =~ " ${service} " ]]; then
        error "Unknown service: $service"
        echo "Available services: ${SERVICES[*]}"
        exit 1
    fi
}

get_repo_url() {
    local service="$1"
    echo "@s3BaseUrl@/@bucketPrefix@/${service}"
}

setup_restic_env() {
    local service="$1"
    local repo=$(get_repo_url "$service")

    # Source the environment file for credentials
    if [[ -f "/run/secrets/backup-envfile" ]]; then
        set -a
        source /run/secrets/backup-envfile
        set +a
    fi

    export RESTIC_REPOSITORY="$repo"
    export RESTIC_PASSWORD_FILE="/run/secrets/backup-passwordfile"
}

check_and_init_repo() {
    local service="$1"

    setup_restic_env "$service"

    # Check if repository exists by trying to get snapshots
    if ! restic snapshots --quiet >/dev/null 2>&1; then
        warn "Repository does not exist for $service. Initializing..."

        if restic init; then
            success "Repository initialized successfully for $service"
        else
            error "Failed to initialize repository for $service"
            return 1
        fi
    fi

    return 0
}

list_services() {
    echo "Configured backup services:"
    echo ""
    printf "%-20s %-15s %-30s\n" "Service" "Type" "Repository"
    printf "%-20s %-15s %-30s\n" "-------" "----" "----------"

    for service in "${SERVICES[@]}"; do
        case "$service" in
            *-db)
                type="Database"
                ;;
            *)
                type="Files"
                ;;
        esac
        repo=$(get_repo_url "$service")
        printf "%-20s %-15s %-50s\n" "$service" "$type" "$repo"
    done
}

show_status() {
    local service="${1:-all}"

    if [[ "$service" == "all" ]]; then
        echo "Backup service status:"
        echo ""
        for svc in "${SERVICES[@]}"; do
            show_service_status "$svc"
        done
    else
        validate_service "$service"
        show_service_status "$service"
    fi
}

show_service_status() {
    local service="$1"
    local service_name="restic-backups-${service}.service"

    echo "=== $service ==="

    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        success "Service is currently running"
    elif systemctl list-unit-files "$service_name" 2>/dev/null | grep -q "$service_name"; then
        echo "Service is available"

        # Check last run status
        local last_run=$(systemctl show "$service_name" -p ExecMainStartTimestamp --value)
        if [[ -n "$last_run" && "$last_run" != "n/a" ]]; then
            echo "Last run: $last_run"

            # Check if it succeeded
            local status_output=$(SYSTEMD_COLORS=false systemctl status "$service_name" --no-pager)
            if echo "$status_output" | grep -q "Main PID.*code=exited, status=0/SUCCESS"; then
                success "Last backup completed successfully"
            else
                warn "Last backup may have failed - check logs with: journalctl -u $service_name"
            fi
        else
            echo "No previous runs found"
        fi
    else
        warn "Service not found or not enabled"
    fi

    # Show next scheduled run
    local timer_name="restic-backups-${service}.timer"
    if systemctl is-enabled --quiet "$timer_name" 2>/dev/null; then
        local next_run=$(systemctl list-timers "$timer_name" --no-legend --no-pager | awk '{print $1, $2, $3}')
        if [[ -n "$next_run" ]]; then
            echo "Next scheduled run: $next_run"
        fi
    fi

    echo ""
}

run_backup() {
    local service="$1"
    validate_service "$service"

    local service_name="restic-backups-${service}.service"

    log "Starting backup for service: $service"

    if systemctl start "$service_name"; then
        log "Backup started. Monitoring progress..."

        # Wait for service to start and monitor
        sleep 2
        while systemctl is-active --quiet "$service_name"; do
            echo -n "."
            sleep 5
        done
        echo ""

        local status_output=$(SYSTEMD_COLORS=false systemctl status "$service_name" --no-pager)
        if echo "$status_output" | grep -q "Main PID.*code=exited, status=0/SUCCESS"; then
            success "Backup completed successfully for $service"
        else
            error "Backup failed for $service"
            echo "Check logs with: journalctl -u $service_name"
            exit 1
        fi
    else
        error "Failed to start backup service for $service"
        exit 1
    fi
}

list_snapshots() {
    local service="$1"
    validate_service "$service"

    local repo=$(get_repo_url "$service")

    log "Listing snapshots for $service..."
    echo "Repository: $repo"
    echo ""

    # Check and initialize repository if needed
    check_and_init_repo "$service" || exit 1

    restic snapshots --tag "$service" || {
        error "Failed to list snapshots. Check credentials or repository access."
        exit 1
    }
}

restore_snapshot() {
    local service="$1"
    local snapshot_id="$2"
    local target_path="$3"

    validate_service "$service"

    if [[ -z "$snapshot_id" || -z "$target_path" ]]; then
        error "Missing snapshot ID or target path"
        usage
        exit 1
    fi

    local repo=$(get_repo_url "$service")

    log "Restoring $service from snapshot $snapshot_id to $target_path..."

    # Check and initialize repository if needed
    check_and_init_repo "$service" || exit 1

    # Create target directory
    mkdir -p "$target_path"

    if restic restore "$snapshot_id" --target "$target_path" --tag "$service"; then
        success "Restore completed successfully"
        echo "Restored files are in: $target_path"
    else
        error "Restore failed"
        exit 1
    fi
}

init_repository() {
    local service="$1"
    validate_service "$service"

    local repo=$(get_repo_url "$service")

    log "Initializing repository for $service..."
    echo "Repository: $repo"

    setup_restic_env "$service"

    if restic init; then
        success "Repository initialized successfully for $service"
    else
        warn "Repository may already exist or initialization failed"
    fi
}

# Main command handling
case "${1:-}" in
    "list-services")
        list_services
        ;;
    "status")
        show_status "${2:-all}"
        ;;
    "backup")
        if [[ -z "${2:-}" ]]; then
            error "Service name required for backup command"
            usage
            exit 1
        fi
        run_backup "$2"
        ;;
    "list-snapshots")
        if [[ -z "${2:-}" ]]; then
            error "Service name required for list-snapshots command"
            usage
            exit 1
        fi
        list_snapshots "$2"
        ;;
    "restore")
        if [[ -z "${2:-}" || -z "${3:-}" || -z "${4:-}" ]]; then
            error "Service name, snapshot ID, and target path required for restore command"
            usage
            exit 1
        fi
        restore_snapshot "$2" "$3" "$4"
        ;;
    "init")
        if [[ -z "${2:-}" ]]; then
            error "Service name required for init command"
            usage
            exit 1
        fi
        init_repository "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac
