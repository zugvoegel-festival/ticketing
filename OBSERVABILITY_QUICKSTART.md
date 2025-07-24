# Grafana Stack (LGTM) - Quick Start Guide

This guide will help you deploy the complete observability stack to your Zugvoegel Festival ticketing infrastructure.

## 🚀 Quick Deployment

### 1. Configure Grafana Secrets (SOPS)
Before deployment, set up your secure Grafana secrets using SOPS:

```bash
# Edit the encrypted secrets file
sops secrets/secrets.yaml

# Add these lines (uncomment and set your values):
# grafana-admin-password: "your-very-secure-password"
# grafana-secret-key: "your-secure-secret-key"
```

**Tip**: Generate a secure secret key with: `openssl rand -hex 32`

See `SOPS_GRAFANA_SETUP.md` for detailed SOPS setup instructions.

### 2. Configuration is Already Added
The observability stack has been added to your `configuration.nix`:

```nix
services.observability = {
  enable = true;
  host = "grafana.zugvoegelfestival.org";
  acmeMail = "webmaster@zugvoegelfestival.org";
  retention = {
    loki = "30d";
    mimir = "15d";
    tempo = "7d";
  };
};
```

Note: The Grafana admin password is now securely managed via SOPS instead of being in the configuration file.

### 3. Update DNS Records
Before deployment, ensure your DNS points to your server:
```
grafana.zugvoegelfestival.org → YOUR_SERVER_IP
```

### 4. Deploy the Changes
```bash
# Build and switch to the new configuration
sudo nixos-rebuild switch

# Or if you're using the deployment script
./update-and-deploy.sh
```

### 5. Verify Services
Check that all services are running:
```bash
sudo systemctl status grafana
sudo systemctl status loki
sudo systemctl status tempo
sudo systemctl status prometheus
sudo systemctl status promtail
```

### 6. Access Grafana
1. Open https://grafana.zugvoegelfestival.org
2. Login with:
   - Username: `admin`
   - Password: `your-very-secure-password` (the one you set in SOPS)

## 📊 What You Get Immediately

### Pre-configured Dashboards
- **System Overview**: CPU, Memory, Disk usage at a glance
- **Node Exporter**: Detailed system metrics and performance
- **Loki Logs**: Centralized log viewing and search

### Auto-discovered Services
- Pretix ticketing application
- Schwarmplaner event management
- Bank automation service
- System services via systemd journal

### Built-in Alerting
- High CPU usage (>80% for 5 minutes)
- High memory usage (>90% for 5 minutes)  
- Low disk space (>85% usage for 5 minutes)

## 🔧 Customization

### Change Grafana Admin Password
The admin password is managed via SOPS. To change it:

1. Edit the encrypted secrets file:
```bash
sops secrets/secrets.yaml
```

2. Update the password:
```yaml
grafana-admin-password: "your-new-secure-password"
```

3. Rebuild and restart:
```bash
sudo nixos-rebuild switch
sudo systemctl restart grafana
```

### Adjust Retention Periods
```nix
services.observability.retention = {
  loki = "45d";    # Keep logs for 45 days
  mimir = "30d";   # Keep metrics for 30 days
  tempo = "14d";   # Keep traces for 14 days
};
```

### Change Data Storage Location
```nix
services.observability.dataPath = "/mnt/observability-data";
```

## 🔍 Using the Stack

### Viewing Logs
1. Go to Grafana → Explore
2. Select "Loki" as datasource
3. Use queries like:
   - `{job="systemd-journal"}` - All system logs
   - `{job="nginx"}` - Web server logs
   - `{unit="pretix.service"}` - Pretix application logs

### Checking Metrics
1. Go to Grafana → Explore
2. Select "Prometheus" as datasource
3. Use queries like:
   - `up` - Service availability
   - `node_cpu_seconds_total` - CPU metrics
   - `node_memory_MemAvailable_bytes` - Memory usage

### Distributed Tracing
1. Go to Grafana → Explore
2. Select "Tempo" as datasource
3. Use trace IDs or service filters

## 📈 Resource Usage

Expected resource consumption:
- **CPU**: 5-10% additional usage
- **Memory**: 1-2GB RAM
- **Disk**: Depends on retention settings
  - Logs: ~100MB/day typical
  - Metrics: ~50MB/day typical
  - Traces: ~20MB/day typical

## 🛡️ Security Features

- **SSL/TLS**: Automatic Let's Encrypt certificates
- **Authentication**: Admin login required for Grafana
- **Firewall**: Only necessary ports opened
- **Internal Communication**: Services bound to localhost

## 🚨 Troubleshooting

### Service Won't Start
```bash
# Check logs
sudo journalctl -u grafana -f
sudo journalctl -u loki -f

# Verify configuration
sudo nixos-rebuild dry-build
```

### Can't Access Grafana
1. Check if service is running: `sudo systemctl status grafana`
2. Verify DNS resolution: `nslookup grafana.zugvoegelfestival.org`
3. Check nginx logs: `sudo journalctl -u nginx -f`
4. Verify certificate: `sudo systemctl status acme-grafana.zugvoegelfestival.org.service`

### High Disk Usage
1. Check data directory: `sudo du -sh /var/lib/observability/*`
2. Adjust retention periods in configuration
3. Manually clean old data: `sudo find /var/lib/observability -name "*.db" -mtime +30 -delete`

### Missing Metrics/Logs
1. Check promtail: `sudo systemctl status promtail`
2. Verify prometheus targets: Visit http://localhost:9090/targets
3. Check node-exporter: `curl http://localhost:9100/metrics`

## 🔗 Integration Examples

### Adding Custom Application Metrics
For applications that expose Prometheus metrics:

```nix
services.observability.prometheus.scrapeConfigs = [
  {
    job_name = "my-app";
    static_configs = [{
      targets = [ "localhost:8080" ];
    }];
    metrics_path = "/metrics";
  }
];
```

### Custom Log Sources
Add additional log sources to promtail:

```nix
services.promtail.configuration.scrape_configs = [
  {
    job_name = "custom-app-logs";
    static_configs = [{
      targets = [ "localhost" ];
      labels = {
        job = "custom-app";
        __path__ = "/var/log/custom-app/*.log";
      };
    }];
  }
];
```

## 📞 Support

For issues specific to the observability stack:
1. Check the module documentation in `modules/observability/README.md`
2. Review service logs with `journalctl`
3. Verify configuration syntax with `nixos-rebuild dry-build`

## 🎯 Next Steps

1. **Set up alerting**: Configure email/Slack notifications
2. **Create custom dashboards**: Build application-specific views
3. **Performance tuning**: Adjust retention and scrape intervals
4. **Backup strategy**: Include important dashboard configurations
5. **Documentation**: Create runbooks for common operational tasks
