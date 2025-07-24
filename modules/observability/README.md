# Observability Module (LGTM Stack)

This module provides a complete observability stack using the LGTM components:
- **L**oki - Log aggregation and storage
- **G**rafana - Visualization and dashboards
- **T**empo - Distributed tracing
- **M**imir - Long-term metrics storage (via Prometheus)

## Features

### 🔍 **Monitoring & Metrics**
- **Prometheus**: Metrics collection with configurable scrape intervals
- **Node Exporter**: System-level metrics (CPU, memory, disk, network)
- **Grafana**: Rich visualization dashboards
- **Alerting**: Built-in alerts for high CPU, memory, and disk usage

### 📊 **Logging**
- **Loki**: Centralized log aggregation
- **Promtail**: Log shipping from systemd journal and nginx
- **Log Retention**: Configurable retention periods
- **Structured Logging**: Automatic label extraction for nginx logs

### 🔗 **Distributed Tracing**
- **Tempo**: Distributed tracing backend
- **Multiple Protocols**: Support for Jaeger, Zipkin, and OpenTelemetry
- **Integration**: Connected to logs and metrics for full observability

### 📈 **Default Dashboards**
- **System Overview**: High-level system health gauges
- **Node Exporter**: Detailed system metrics
- **Loki Logs**: Log exploration and error tracking

## Configuration

### Basic Setup
```nix
services.observability = {
  enable = true;
  host = "grafana.zugvoegelfestival.org";
  acmeMail = "webmaster@zugvoegelfestival.org";
};
```

### Advanced Configuration
```nix
services.observability = {
  enable = true;
  host = "grafana.zugvoegelfestival.org";
  acmeMail = "webmaster@zugvoegelfestival.org";
  
  # Data storage location
  dataPath = "/var/lib/observability";
  
  # Retention periods
  retention = {
    loki = "30d";    # Log retention
    mimir = "15d";   # Metrics retention
    tempo = "7d";    # Traces retention
  };
  
  # Grafana settings
  grafana = {
    adminPassword = "secure-password";
    defaultDashboards = true;
  };
  
  # Prometheus settings
  prometheus = {
    enable = true;
    scrapeInterval = "15s";
  };
};
```

## Access Points

Once deployed, the following services will be available:

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| Grafana | `https://grafana.zugvoegelfestival.org` | 3000 | Main dashboard interface |
| Prometheus | `http://localhost:9090` | 9090 | Metrics database (internal) |
| Loki | `http://localhost:3100` | 3100 | Log aggregation (internal) |
| Tempo | `http://localhost:3200` | 3200 | Tracing backend (internal) |

## Default Dashboards

### System Overview
- CPU, Memory, Disk usage gauges
- Service status overview
- System load metrics
- HTTP request rates

### Node Exporter
- Detailed system metrics
- CPU usage breakdown
- Memory utilization
- Disk I/O statistics
- Network traffic

### Loki Logs
- System journal logs
- Nginx access/error logs
- Error rate tracking by service unit

## Integrations

### Automatic Service Discovery
The module automatically discovers and monitors:
- All systemd services
- Nginx web server
- PostgreSQL (if running)
- Pretix application
- Other services in the ecosystem

### Log Collection
Automatically collects logs from:
- Systemd journal (all services)
- Nginx access and error logs
- Application-specific logs

### Alerting Rules
Pre-configured alerts for:
- High CPU usage (>80% for 5 minutes)
- High memory usage (>90% for 5 minutes)
- Low disk space (>85% usage for 5 minutes)

## Data Storage

All observability data is stored under `/var/lib/observability/` by default:
```
/var/lib/observability/
├── loki/           # Log data and indices
├── grafana/        # Grafana database and configs
├── tempo/          # Distributed traces
├── prometheus/     # Metrics data
└── mimir/          # Long-term metrics (if using Mimir)
```

## Security

- SSL/TLS encryption via Let's Encrypt
- Admin authentication required for Grafana
- Internal services bound to localhost only
- Firewall rules automatically configured

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status grafana
sudo systemctl status loki
sudo systemctl status tempo
sudo systemctl status prometheus
sudo systemctl status promtail
```

### View Logs
```bash
sudo journalctl -u grafana -f
sudo journalctl -u loki -f
sudo journalctl -u tempo -f
```

### Common Issues

1. **Grafana shows "Bad Gateway"**: Check if all backend services are running
2. **No metrics in Prometheus**: Verify node-exporter is running and accessible
3. **Missing logs in Loki**: Check promtail configuration and permissions
4. **High disk usage**: Adjust retention periods in configuration

## Integration with Existing Services

The module automatically integrates with your existing services:

### Pretix Integration
- Monitors Pretix container health
- Collects application logs
- Tracks HTTP request metrics

### Schwarmplaner Integration  
- API response time monitoring
- Frontend performance metrics
- Error rate tracking

### Bank Automation Integration
- Processing job metrics
- Error alerting
- Performance monitoring

## Extending the Setup

### Adding Custom Dashboards
Place JSON dashboard files in `/var/lib/grafana/dashboards/`

### Custom Prometheus Scrape Configs
Extend the `scrapeConfigs` in the module configuration

### Additional Log Sources
Add new `scrape_configs` to the promtail configuration

### Custom Alerts
Add alert rules to the Prometheus `rules` configuration

## Performance Considerations

- **CPU**: Low overhead, typically <5% CPU usage
- **Memory**: ~1-2GB RAM for the full stack
- **Disk**: Depends on retention settings and log volume
- **Network**: Minimal impact, all internal communication

## Backup Recommendations

Include observability data in your backup strategy:
```nix
services.backup.backupDirs = [
  "/var/lib/observability/grafana"  # Dashboards and config
  # Note: Metrics and logs can be regenerated, so backup is optional
];
```
