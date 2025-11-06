#!/usr/bin/env bash
# Simple Audio Transcriber Admin Script
# Focuses on operational tasks, uses NixOS for version management

set -euo pipefail

# Service and container names
SERVICE_NAME="docker-audiotranscriber-pwa.service"
CONTAINER_NAME="audiotranscriber-pwa"
DATA_DIR="/var/lib/audiotranscriber-pwa/data"
BACKUP_DIR="/var/backups/audiotranscriber-pwa"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Simple logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_help() {
    cat << EOF
${BOLD}Audio Transcriber Admin Script${NC}

${BOLD}Usage:${NC} $(basename "$0") <command>

${BOLD}Service Management:${NC}
    status      Show service status and health
    restart     Restart the service
    logs        Show recent logs
    logs-live   Follow logs in real-time
    health      Quick health check

${BOLD}Backup & Restore:${NC}
    backup      Create local backup of data
    restore     Restore from backup (interactive)
    backup-list List available backups

${BOLD}Version Management:${NC}
    version     Show current image version
    deploy      Deploy new version (requires NixOS rebuild)

${BOLD}Examples:${NC}
    $(basename "$0") status
    $(basename "$0") restart
    $(basename "$0") logs-live
    $(basename "$0") backup

${BOLD}Notes:${NC}
    • Version changes require updating configuration.nix and running deploy.sh
    • This script handles operational tasks, NixOS handles configuration
    • Always check status after making changes

EOF
}

# Check if running as root for operations that need it
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This command requires root access. Run with sudo."
    fi
}

# Get service status
get_service_status() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "running"
    elif systemctl is-failed --quiet "$SERVICE_NAME"; then
        echo "failed"
    else
        echo "stopped"
    fi
}

# Get container info
get_container_info() {
    docker ps --filter "name=$CONTAINER_NAME" --format "{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "not-found\tnot-running\tnone"
}

# Calculate uptime
get_uptime() {
    local start_time=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
    if [[ -n "$start_time" && "$start_time" != "n/a" ]]; then
        local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
        local current_epoch=$(date +%s)
        local uptime_seconds=$((current_epoch - start_epoch))
        
        if [[ $uptime_seconds -gt 86400 ]]; then
            echo "$((uptime_seconds / 86400))d $((uptime_seconds % 86400 / 3600))h"
        elif [[ $uptime_seconds -gt 3600 ]]; then
            echo "$((uptime_seconds / 3600))h $((uptime_seconds % 3600 / 60))m"
        elif [[ $uptime_seconds -gt 60 ]]; then
            echo "$((uptime_seconds / 60))m"
        else
            echo "${uptime_seconds}s"
        fi
    else
        echo "n/a"
    fi
}

# Show comprehensive status
show_status() {
    echo -e "${BOLD}Audio Transcriber Status${NC}"
    echo "========================"
    
    local service_status=$(get_service_status)
    local container_info=$(get_container_info)
    local image=$(echo "$container_info" | cut -f1)
    local status=$(echo "$container_info" | cut -f2)
    local ports=$(echo "$container_info" | cut -f3)
    local uptime=$(get_uptime)
    
    # Service status with color coding
    case $service_status in
        "running")
            echo -e "Service: ${GREEN}●${NC} Running ($uptime)"
            ;;
        "failed")
            echo -e "Service: ${RED}●${NC} Failed"
            ;;
        *)
            echo -e "Service: ${YELLOW}●${NC} Stopped"
            ;;
    esac
    
    # Container info
    if [[ "$image" != "not-found" ]]; then
        echo "Container: $CONTAINER_NAME"
        echo "Image: $image"
        echo "Status: $status"
        [[ "$ports" != "none" ]] && echo "Ports: $ports"
    else
        echo -e "Container: ${RED}Not found${NC}"
    fi
    
    # Data directory info
    if [[ -d "$DATA_DIR" ]]; then
        local data_size=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        echo "Data: $DATA_DIR ($data_size)"
    else
        echo -e "Data: ${RED}Directory missing${NC}"
    fi
    
    echo ""
    echo "Quick commands:"
    echo "  $(basename "$0") health    # Run health checks"
    echo "  $(basename "$0") logs-live # Follow logs"
    echo "  $(basename "$0") restart   # Restart service"
}

# Health check
health_check() {
    echo -e "${BOLD}Health Check${NC}"
    echo "============"
    
    local issues=0
    
    # Check service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Service is running"
    else
        warn "Service is not running"
        issues=$((issues + 1))
    fi
    
    # Check container
    if docker ps --filter "name=$CONTAINER_NAME" --quiet | grep -q .; then
        success "Container is running"
    else
        warn "Container is not running"
        issues=$((issues + 1))
    fi
    
    # Check data directory
    if [[ -d "$DATA_DIR" && -r "$DATA_DIR" && -w "$DATA_DIR" ]]; then
        success "Data directory accessible"
    else
        warn "Data directory issues"
        issues=$((issues + 1))
    fi
    
    # Check disk space (warn if less than 1GB)
    local available=$(df "$DATA_DIR" --output=avail 2>/dev/null | tail -1 || echo "0")
    if [[ "$available" -gt 1048576 ]]; then  # 1GB in KB
        success "Sufficient disk space"
    else
        warn "Low disk space"
        issues=$((issues + 1))
    fi
    
    echo ""
    if [[ $issues -eq 0 ]]; then
        success "All checks passed"
        return 0
    else
        warn "$issues issue(s) found"
        return 1
    fi
}

# Restart service
restart_service() {
    check_root
    
    log "Restarting audio transcriber service..."
    
    if systemctl restart "$SERVICE_NAME"; then
        success "Service restart initiated"
        
        # Wait a moment and check status
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            success "Service is now running"
        else
            warn "Service may have issues starting"
            echo "Check logs with: $(basename "$0") logs"
        fi
    else
        error "Failed to restart service"
    fi
}

# Show logs
show_logs() {
    echo -e "${BOLD}Recent Logs${NC}"
    echo "==========="
    journalctl -u "$SERVICE_NAME" --no-pager -n 30 --reverse
}

# Follow logs
follow_logs() {
    echo -e "${BOLD}Following Logs${NC} (Press Ctrl+C to stop)"
    echo "=============="
    journalctl -u "$SERVICE_NAME" -f --no-pager
}

# Show current version
show_version() {
    local container_info=$(get_container_info)
    local image=$(echo "$container_info" | cut -f1)
    
    echo -e "${BOLD}Version Information${NC}"
    echo "==================="
    
    if [[ "$image" != "not-found" ]]; then
        echo "Current image: $image"
        
        # Extract version from image tag if possible
        local version=$(echo "$image" | grep -o ':[^:]*$' | cut -c 2- || echo "unknown")
        echo "Version tag: $version"
    else
        echo "No container running"
    fi
    
    echo ""
    info "To change version:"
    echo "  1. Update 'app-image' in configuration.nix"
    echo "  2. Run ./deploy.sh to deploy changes"
}

# Deploy info
deploy_info() {
    echo -e "${BOLD}Deployment Guide${NC}"
    echo "================"
    echo ""
    info "Audio Transcriber uses NixOS configuration management"
    echo ""
    echo "To deploy a new version:"
    echo "  1. Edit configuration.nix"
    echo "  2. Update the 'app-image' field:"
    echo "     app-image = \"manulinger/audio-transcriber:NEW_VERSION\";"
    echo "  3. Deploy: ./deploy.sh"
    echo "  4. Verify: $(basename "$0") status"
    echo ""
    echo "Current configuration in configuration.nix:"
    grep -A 5 -B 5 "app-image" /home/manu/repos/zv/ticketing/configuration.nix 2>/dev/null || echo "  (configuration not found in expected location)"
}

# Create backup
create_backup() {
    check_root
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_$timestamp.tar.gz"
    
    log "Creating backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Create backup (don't stop service for read-only backup)
    if [[ -d "$DATA_DIR" ]]; then
        if tar -czf "$backup_file" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null; then
            local size=$(du -sh "$backup_file" | cut -f1)
            success "Backup created: $(basename "$backup_file") ($size)"
        else
            error "Backup failed"
        fi
    else
        error "Data directory not found: $DATA_DIR"
    fi
}

# List backups
list_backups() {
    echo -e "${BOLD}Available Backups${NC}"
    echo "================="
    
    if [[ -d "$BACKUP_DIR" ]] && ls "$BACKUP_DIR"/backup_*.tar.gz >/dev/null 2>&1; then
        echo "Location: $BACKUP_DIR"
        echo ""
        ls -la "$BACKUP_DIR"/backup_*.tar.gz | while read -r line; do
            local file=$(echo "$line" | awk '{print $9}')
            local size=$(echo "$line" | awk '{print $5}')
            local date=$(echo "$line" | awk '{print $6, $7, $8}')
            local basename_file=$(basename "$file")
            echo "  $basename_file"
            echo "    Size: $(numfmt --to=iec $size), Date: $date"
            echo ""
        done
    else
        info "No backups found"
        echo "Create one with: $(basename "$0") backup"
    fi
}

# Restore from backup
restore_backup() {
    check_root
    
    # Show available backups
    echo -e "${BOLD}Restore from Backup${NC}"
    echo "==================="
    
    if ! ls "$BACKUP_DIR"/backup_*.tar.gz >/dev/null 2>&1; then
        error "No backups found in $BACKUP_DIR"
    fi
    
    echo "Available backups:"
    local backups=($(ls "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
    for i in "${!backups[@]}"; do
        local backup="${backups[$i]}"
        local size=$(du -sh "$backup" | cut -f1)
        echo "  $((i+1)). $(basename "$backup") ($size)"
    done
    
    echo ""
    read -p "Enter backup number (or 'q' to quit): " choice
    
    if [[ "$choice" == "q" ]]; then
        info "Restore cancelled"
        return 0
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
        error "Invalid choice"
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    warn "This will replace current data with: $(basename "$selected_backup")"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Restore cancelled"
        return 0
    fi
    
    log "Stopping service..."
    systemctl stop "$SERVICE_NAME"
    
    log "Restoring data..."
    if [[ -d "$DATA_DIR" ]]; then
        mv "$DATA_DIR" "${DATA_DIR}.backup.$(date +%s)"
    fi
    
    if tar -xzf "$selected_backup" -C "$(dirname "$DATA_DIR")"; then
        success "Data restored"
        chown -R 1000:1000 "$DATA_DIR"
        
        log "Starting service..."
        systemctl start "$SERVICE_NAME"
        
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            success "Service restarted successfully"
        else
            warn "Service may have issues starting"
        fi
    else
        error "Restore failed"
    fi
}

# Main command handling
case "${1:-help}" in
    "status"|"st")
        show_status
        ;;
    "health"|"check")
        health_check
        ;;
    "restart"|"rs")
        restart_service
        ;;
    "logs")
        show_logs
        ;;
    "logs-live"|"logs-follow")
        follow_logs
        ;;
    "version"|"ver")
        show_version
        ;;
    "deploy")
        deploy_info
        ;;
    "backup")
        create_backup
        ;;
    "backup-list"|"backups")
        list_backups
        ;;
    "restore")
        restore_backup
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        error "Unknown command: $1. Use 'help' to see available commands."
        ;;
esac