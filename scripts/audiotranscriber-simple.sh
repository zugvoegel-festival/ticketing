#!/usr/bin/env bash
# Simple Audio Transcriber Admin Script
# Focuses on operational tasks, uses NixOS for version management

set -euo pipefail

# Service and container names
SERVICE_NAME="docker-audiotranscriber-pwa.service"
CONTAINER_NAME="audiotranscriber-pwa"
DATA_DIR="/var/lib/audiotranscriber-pwa/data"
BACKUP_DIR="/var/backups/audiotranscriber-pwa"

# Color detection function
setup_colors() {
    if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        RED='\033[0;31m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color
    else
        GREEN=''
        YELLOW=''
        RED=''
        BLUE=''
        CYAN=''
        BOLD=''
        NC=''
    fi
}

# Initialize colors
setup_colors

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
    echo -e "${BOLD}Audio Transcriber Admin Script${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} $(basename "$0") <command>"
    echo ""
    echo -e "${BOLD}Service Management:${NC}"
    echo "    status      Show service status and health"
    echo "    restart     Restart the service"
    echo "    logs        Show recent logs"
    echo "    logs-live   Follow logs in real-time"
    echo "    health      Quick health check"
    echo ""
    echo -e "${BOLD}Backup & Restore:${NC}"
    echo "    backup      Create local backup of data"
    echo "    restore     Restore from backup (interactive)"
    echo "    backup-list List available backups"
    echo ""
    echo -e "${BOLD}Version Management:${NC}"
    echo "    version        Show current image version"
    echo "    deploy <ver>   Deploy specific version (auto-commit & deploy)"
    echo "    rollback       Rollback to previous version"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "    $(basename "$0") status"
    echo "    $(basename "$0") restart"
    echo "    $(basename "$0") logs-live"
    echo "    $(basename "$0") deploy v1.2.3"
    echo "    $(basename "$0") rollback"
    echo "    $(basename "$0") backup"
    echo ""
    echo -e "${BOLD}Notes:${NC}"
    echo "    • Version deploy sets global systemd environment variable"
    echo "    • Changes persist across NixOS deployments"
    echo "    • Rollback restores the previous version from backup"
    echo "    • Always verify deployment with status/health commands"
    echo ""
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
    
    # Show configured version from environment
    local env_version=$(systemctl show-environment | grep "AUDIOTRANSCRIBER_VERSION=" | cut -d'=' -f2)
    if [[ -n "$env_version" ]]; then
        echo "Configured version: $env_version (from environment)"
    else
        echo "Configured version: test (default)"
    fi
    
    echo ""
    info "Version management commands:"
    echo "  ./$(basename $0) deploy <version>  - Deploy specific version"
    echo "  ./$(basename $0) rollback         - Rollback to previous version"
}

# Deploy specific version
deploy_version() {
    local new_version="$1"
    
    if [[ -z "$new_version" ]]; then
        error "Version required. Usage: ./$(basename $0) deploy <version>"
        return 1
    fi
    
    echo -e "${BOLD}Deploying Version: $new_version${NC}"
    echo "================================="
    
    # Backup current version
    local current_version=$(systemctl show-environment | grep "AUDIOTRANSCRIBER_VERSION=" | cut -d'=' -f2)
    if [[ -z "$current_version" ]]; then
        current_version="test"  # default fallback
    fi
    echo "Previous version: $current_version" > .version_backup
    info "Backed up current version: $current_version"
    
    # Set new version in global environment
    info "Setting global environment variable..."
    systemctl set-environment AUDIOTRANSCRIBER_VERSION="$new_version"
    success "Set AUDIOTRANSCRIBER_VERSION=$new_version in systemd environment"
    
    # Restart the service to pick up new version
    info "Restarting service to apply new version..."
    systemctl restart docker-audiotranscriber-pwa.service
    
    success "Version deployment completed!"
    echo ""
    info "Waiting 15 seconds for service to start..."
    sleep 15
    
    # Verify deployment
    info "Verifying deployment..."
    if health_check_silent; then
        success "Service is healthy after deployment ✓"
        
        # Show actual running version
        local container_info=$(get_container_info)
        local running_image=$(echo "$container_info" | cut -f1)
        info "Running image: $running_image"
    else
        warning "Service health check failed - checking status..."
        show_status
        return 1
    fi
}

# Silent health check for automated use
health_check_silent() {
    local container_info=$(get_container_info)
    local container_id=$(echo "$container_info" | cut -f2)
    local status=$(echo "$container_info" | cut -f3)
    
    if [[ "$container_id" != "not-found" && "$status" == "running" ]]; then
        return 0
    else
        return 1
    fi
}

# Rollback to previous version
rollback_version() {
    echo -e "${BOLD}Rolling Back Version${NC}"
    echo "==================="
    
    if [[ ! -f ".version_backup" ]]; then
        error "No version backup found! Cannot rollback."
        return 1
    fi
    
    local previous_version=$(cat .version_backup | grep "Previous version:" | cut -d' ' -f3)
    
    if [[ -z "$previous_version" ]]; then
        error "Could not determine previous version from backup."
        return 1
    fi
    
    info "Rolling back to version: $previous_version"
    
    # Set previous version in global environment
    if [[ "$previous_version" == "test" ]]; then
        # Remove environment variable to use default
        info "Removing environment override to use default version..."
        systemctl unset-environment AUDIOTRANSCRIBER_VERSION
        success "Removed AUDIOTRANSCRIBER_VERSION from systemd environment"
    else
        # Set to previous version
        systemctl set-environment AUDIOTRANSCRIBER_VERSION="$previous_version"
        success "Set AUDIOTRANSCRIBER_VERSION=$previous_version in systemd environment"
    fi
    
    # Restart service to apply rollback
    info "Restarting service to apply rollback..."
    systemctl restart docker-audiotranscriber-pwa.service
    
    success "Rollback completed successfully!"
    rm -f .version_backup
    
    echo ""
    info "Waiting 15 seconds for service to start..."
    sleep 15
    
    # Verify rollback
    info "Verifying rollback..."
    if health_check_silent; then
        success "Service is healthy after rollback ✓"
        
        # Show actual running version
        local container_info=$(get_container_info)
        local running_image=$(echo "$container_info" | cut -f1)
        info "Running image: $running_image"
    else
        warning "Service health check failed - checking status..."
        show_status
        return 1
    fi
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
        if [[ -n "$2" ]]; then
            deploy_version "$2"
        else
            deploy_info
        fi
        ;;
    "rollback"|"rb")
        rollback_version
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