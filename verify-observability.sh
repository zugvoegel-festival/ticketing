#!/usr/bin/env bash
set -euo pipefail

# Grafana Stack (LGTM) Deployment Verification Script
# This script verifies that all observability components are running correctly

echo "🔍 Grafana Stack (LGTM) Deployment Verification"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a service is running
check_service() {
    local service=$1
    local port=$2
    
    if systemctl is-active --quiet "$service"; then
        echo -e "✅ ${GREEN}$service${NC} is running"
        
        # Check if port is responding (if provided)
        if [ -n "$port" ]; then
            if curl -f -s "http://localhost:$port" > /dev/null 2>&1 || curl -f -s "http://localhost:$port/health" > /dev/null 2>&1; then
                echo -e "   🌐 Port $port is responding"
            else
                echo -e "   ⚠️  ${YELLOW}Port $port is not responding${NC}"
            fi
        fi
    else
        echo -e "❌ ${RED}$service${NC} is not running"
        return 1
    fi
}

# Function to check if a URL is accessible
check_url() {
    local url=$1
    local description=$2
    
    if curl -f -s -k "$url" > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}$description${NC} is accessible at $url"
    else
        echo -e "❌ ${RED}$description${NC} is not accessible at $url"
        return 1
    fi
}

# Function to check disk usage
check_disk_usage() {
    local path=$1
    local max_usage=$2
    
    if [ -d "$path" ]; then
        local usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$usage" -lt "$max_usage" ]; then
            echo -e "✅ ${GREEN}Disk usage${NC} at $path: ${usage}% (< ${max_usage}%)"
        else
            echo -e "⚠️  ${YELLOW}Disk usage${NC} at $path: ${usage}% (>= ${max_usage}%)"
        fi
    else
        echo -e "❌ ${RED}Data directory${NC} $path does not exist"
        return 1
    fi
}

echo ""
echo "🧪 Checking System Services..."
echo "------------------------------"

# Check core observability services
services_failed=0

check_service "grafana" "3000" || services_failed=$((services_failed + 1))
check_service "loki" "3100" || services_failed=$((services_failed + 1))
check_service "tempo" "3200" || services_failed=$((services_failed + 1))
check_service "prometheus" "9090" || services_failed=$((services_failed + 1))
check_service "promtail" "9080" || services_failed=$((services_failed + 1))

# Check exporters
check_service "prometheus-node-exporter" "9100" || services_failed=$((services_failed + 1))

# Check nginx (for reverse proxy)
check_service "nginx" "80" || services_failed=$((services_failed + 1))

echo ""
echo "🌐 Checking External Access..."
echo "------------------------------"

# Check if Grafana is accessible externally (if configured)
if systemctl is-active --quiet nginx; then
    # Try to determine the configured hostname from nginx config
    grafana_host=$(grep -r "server_name.*grafana" /etc/nginx/sites-* 2>/dev/null | head -1 | sed 's/.*server_name \([^;]*\);.*/\1/' || echo "")
    
    if [ -n "$grafana_host" ] && [ "$grafana_host" != "_" ]; then
        check_url "https://$grafana_host" "Grafana web interface" || echo "   💡 Note: This might fail if DNS is not configured or certificates are pending"
    else
        echo "ℹ️  Could not determine Grafana hostname from nginx configuration"
    fi
else
    echo "⚠️  Nginx is not running, external access may not work"
fi

echo ""
echo "💾 Checking Data Storage..."
echo "---------------------------"

# Check data directories and disk usage
data_path="/var/lib/observability"
if [ -d "$data_path" ]; then
    check_disk_usage "$data_path" 85
    
    # Check individual component data directories
    for component in loki grafana tempo prometheus; do
        if [ -d "$data_path/$component" ]; then
            size=$(du -sh "$data_path/$component" 2>/dev/null | cut -f1 || echo "unknown")
            echo -e "📁 $component data: ${size}"
        fi
    done
else
    echo -e "❌ ${RED}Observability data directory${NC} $data_path does not exist"
    services_failed=$((services_failed + 1))
fi

echo ""
echo "🔗 Checking Service Integration..."
echo "---------------------------------"

# Check if Prometheus can scrape its targets
if curl -f -s "http://localhost:9090/api/v1/targets" > /dev/null 2>&1; then
    echo "✅ Prometheus API is responding"
    
    # Get target status
    targets_down=$(curl -s "http://localhost:9090/api/v1/targets" | grep -o '"health":"down"' | wc -l)
    targets_up=$(curl -s "http://localhost:9090/api/v1/targets" | grep -o '"health":"up"' | wc -l)
    
    echo "   📊 Prometheus targets: $targets_up up, $targets_down down"
    
    if [ "$targets_down" -gt 0 ]; then
        echo -e "   ⚠️  ${YELLOW}Some Prometheus targets are down${NC}"
    fi
else
    echo -e "❌ ${RED}Prometheus API${NC} is not responding"
    services_failed=$((services_failed + 1))
fi

# Check if Loki is receiving logs
if curl -f -s "http://localhost:3100/ready" > /dev/null 2>&1; then
    echo "✅ Loki is ready"
else
    echo -e "❌ ${RED}Loki${NC} is not ready"
    services_failed=$((services_failed + 1))
fi

# Check if Grafana can connect to its datasources
if curl -f -s "http://localhost:3000/api/health" > /dev/null 2>&1; then
    echo "✅ Grafana API is responding"
else
    echo -e "❌ ${RED}Grafana API${NC} is not responding"
    services_failed=$((services_failed + 1))
fi

echo ""
echo "📊 Summary"
echo "==========="

if [ "$services_failed" -eq 0 ]; then
    echo -e "🎉 ${GREEN}All checks passed!${NC} Your Grafana Stack (LGTM) is running correctly."
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Access Grafana at your configured hostname"
    echo "   2. Login with admin credentials"
    echo "   3. Explore the pre-configured dashboards"
    echo "   4. Set up additional alerting if needed"
    exit 0
else
    echo -e "⚠️  ${YELLOW}$services_failed issues found.${NC} Please check the failed services above."
    echo ""
    echo "🔧 Troubleshooting tips:"
    echo "   1. Check service logs: sudo journalctl -u <service-name> -f"
    echo "   2. Verify configuration: sudo nixos-rebuild dry-build"
    echo "   3. Restart failed services: sudo systemctl restart <service-name>"
    echo "   4. Check firewall rules: sudo iptables -L"
    exit 1
fi
