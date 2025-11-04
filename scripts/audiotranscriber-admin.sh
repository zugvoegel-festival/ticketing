#!/usr/bin/env bash
# Audio Transcriber Management Script
# Provides commands to restart, backup, and restore the audio transcriber service

set -euo pipefail

CONTAINER_NAME="audiotranscriber-pwa"
DATA_DIR="/var/lib/audiotranscriber-pwa/data"
BACKUP_DIR="/var/backups/audiotranscriber-pwa"
SERVICE_NAME="docker-audiotranscriber-pwa.service"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

show_help() {
    cat << EOF
Audio Transcriber Management Script

Usage: $(basename "$0") <command>

Commands:
    restart        Restart the audio transcriber service
    backup         Create a local backup of the audio transcriber database/data
    backup-restic  Create a backup using restic (to remote S3 storage)
    restore        Restore the audio transcriber database/data from local backup
    status         Show current status of the service
    logs           Show recent logs from the service
    logs-restic    Show logs from the restic backup service
    help           Show this help message

Examples:
    $(basename "$0") restart
    $(basename "$0") backup
    $(basename "$0") backup-restic
    $(basename "$0") restore /path/to/backup.tar.gz
    $(basename "$0") logs-restic

EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

service_status() {
    systemctl is-active "$SERVICE_NAME" || true
}

restart_service() {
    log "Restarting audio transcriber service..."
    
    # Stop the service
    log "Stopping $SERVICE_NAME..."
    systemctl stop "$SERVICE_NAME" || warn "Failed to stop service gracefully"
    
    # Wait a moment
    sleep 2
    
    # Start the service
    log "Starting $SERVICE_NAME..."
    systemctl start "$SERVICE_NAME"
    
    # Check status
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Service restarted successfully"
        log "Status: $(service_status)"
    else
        error "Failed to restart service"
    fi
}

backup_data() {
    log "Creating backup of audio transcriber data..."
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Generate backup filename with timestamp
    BACKUP_FILE="$BACKUP_DIR/audiotranscriber-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    # Stop the service before backup
    log "Stopping service for consistent backup..."
    systemctl stop "$SERVICE_NAME" || warn "Service was not running"
    
    # Create the backup
    log "Creating backup archive: $BACKUP_FILE"
    if [[ -d "$DATA_DIR" ]]; then
        tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
        log "Backup created successfully: $BACKUP_FILE"
        log "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
    else
        error "Data directory $DATA_DIR does not exist"
    fi
    
    # Restart the service
    log "Restarting service..."
    systemctl start "$SERVICE_NAME"
    
    # Clean up old backups (keep last 10)
    log "Cleaning up old backups (keeping last 10)..."
    cd "$BACKUP_DIR"
    ls -t audiotranscriber-backup-*.tar.gz | tail -n +11 | xargs -r rm -f
    
    log "Backup completed successfully"
}

restore_data() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        error "Please specify a backup file to restore from"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file does not exist: $backup_file"
    fi
    
    log "Restoring audio transcriber data from: $backup_file"
    
    # Confirm before restoring
    read -p "This will overwrite current data. Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restore cancelled"
        exit 0
    fi
    
    # Stop the service
    log "Stopping service..."
    systemctl stop "$SERVICE_NAME" || warn "Service was not running"
    
    # Backup current data before restore
    if [[ -d "$DATA_DIR" ]]; then
        CURRENT_BACKUP="$BACKUP_DIR/pre-restore-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        log "Creating backup of current data: $CURRENT_BACKUP"
        tar -czf "$CURRENT_BACKUP" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
    fi
    
    # Remove current data directory
    log "Removing current data directory..."
    rm -rf "$DATA_DIR"
    
    # Extract backup
    log "Extracting backup..."
    mkdir -p "$(dirname "$DATA_DIR")"
    tar -xzf "$backup_file" -C "$(dirname "$DATA_DIR")"
    
    # Set proper permissions
    log "Setting proper permissions..."
    chown -R 1000:1000 "$DATA_DIR"
    chmod -R 755 "$DATA_DIR"
    
    # Restart the service
    log "Restarting service..."
    systemctl start "$SERVICE_NAME"
    
    # Check status
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Data restored and service restarted successfully"
    else
        error "Service failed to start after restore"
    fi
}

backup_restic() {
    log "Creating restic backup of audio transcriber data..."
    
    # Check if restic backup service exists
    if ! systemctl list-unit-files | grep -q "restic-backups-audiotranscriber-pwa.service"; then
        error "Restic backup service not found. Please ensure the backup module is properly configured."
    fi

    # Trigger the restic backup service
    log "Starting restic backup service..."
    systemctl start restic-backups-audiotranscriber-pwa.service

    # Show initial logs
    log "Showing backup logs (press Ctrl+C to stop following logs)..."
    echo "----------------------------------------"

    # Follow logs for a bit to show initial progress
    timeout 10 journalctl -u restic-backups-audiotranscriber-pwa.service -f --no-pager --since "1 minute ago" 2>/dev/null || true
    
    echo "----------------------------------------"
    log "Monitoring backup progress..."
    
    # Monitor the service for up to 30 minutes
    local timeout=1800  # 30 minutes
    local elapsed=0
    local interval=10
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(systemctl is-active restic-backups-audiotranscriber-pwa.service)
        
        if [[ "$status" == "inactive" ]]; then
            # Service finished, check if it was successful
            if systemctl is-failed restic-backups-audiotranscriber-pwa.service >/dev/null 2>&1; then
                error "Restic backup failed. Recent logs:"
                journalctl -u restic-backups-audiotranscriber-pwa.service --no-pager -n 20 --since "10 minutes ago"
                echo ""
                error "Full logs available with: audiotranscriber-admin logs-restic"
            else
                log "Restic backup completed successfully"
                
                # Show backup status/info
                log "Final backup information:"
                journalctl -u restic-backups-audiotranscriber-pwa.service --no-pager -n 15 --since "10 minutes ago" | grep -E "(repository|snapshot|backup)" || true
                return 0
            fi
        elif [[ "$status" == "active" ]]; then
            log "Backup in progress... (${elapsed}s elapsed)"
            # Show recent log lines to indicate progress
            echo "  Latest activity:"
            journalctl -u restic-backups-audiotranscriber-pwa.service --no-pager -n 3 --since "30 seconds ago" | tail -n 2 | sed 's/^/    /' || true
        elif [[ "$status" == "failed" ]]; then
            error "Restic backup service failed. Recent logs:"
            journalctl -u restic-backups-audiotranscriber-pwa.service --no-pager -n 20 --since "10 minutes ago"
            echo ""
            error "Full logs available with: audiotranscriber-admin logs-restic"
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    warn "Backup is taking longer than expected (${timeout}s). It may still be running in the background."
    log "Check status with: systemctl status restic-backups-audiotranscriber-pwa.service"
    log "View logs with: audiotranscriber-admin logs-restic"
}

show_status() {
    log "Audio Transcriber Service Status:"
    echo "  Service: $SERVICE_NAME"
    echo "  Status: $(service_status)"
    echo "  Container: $CONTAINER_NAME"
    echo "  Data Directory: $DATA_DIR"
    echo "  Backup Directory: $BACKUP_DIR"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        echo "  Docker Container:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
    else
        echo "  Docker Container: Not running"
    fi
}

show_logs() {
    log "Recent logs from $SERVICE_NAME:"
    journalctl -u "$SERVICE_NAME" --no-pager -n 50 --reverse
}

show_restic_logs() {
    log "Recent logs from restic backup service:"
    echo "----------------------------------------"
    echo "Service Status:"
    systemctl status restic-backups-audiotranscriber-pwa.service --no-pager || true
    echo ""
    echo "Recent Logs:"
    journalctl -u restic-backups-audiotranscriber-pwa.service --no-pager -n 100 --reverse
}

# Main script logic
case "${1:-help}" in
    "restart")
        check_root
        restart_service
        ;;
    "backup")
        check_root
        backup_data
        ;;
    "backup-restic")
        check_root
        backup_restic
        ;;
    "restore")
        check_root
        restore_data "${2:-}"
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "logs-restic")
        show_restic_logs
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        error "Unknown command: $1. Use 'help' to see available commands."
        ;;
esac