# Zugvögel Festival Infrastructure

A comprehensive NixOS-based deployment for event management infrastructure, designed for the Zugvögel Festival. This repository provides a complete, production-ready setup for ticketing, volunteer management, task organization, and supporting services.

## 🚀 Features

### Core Services
- **[Pretix](https://pretix.eu/)**: Professional event ticketing system with payment processing
- **[Schwarmplaner](https://github.com/zugvoegel-festival/schwarmplaner)**: Custom volunteer shift planning and management

### Infrastructure & Storage
- **Bank Automation**: Automated bank transaction processing and reconciliation
- **Automated Backup**: Comprehensive backup solution with encryption and remote storage

### Monitoring & Observability
- **Simplified Monitoring Stack**: Complete observability with Grafana dashboards, Prometheus metrics, Loki log aggregation, and Promtail collection
- **SSL/TLS**: Automatic HTTPS certificates via Let's Encrypt
- **Nginx Reverse Proxy**: Professional routing and load balancing

## 🛠 Technology Stack

- **Base OS**: NixOS (declarative, reproducible system configuration)
- **Deployment**: Nix Flakes with nixos-anywhere for infrastructure-as-code
- **Secrets Management**: sops-nix for encrypted configuration
- **Containerization**: Docker with custom images for services
- **Monitoring**: Prometheus + Grafana + Loki stack
- **Web Server**: Nginx with automatic SSL certificate management

## 📋 Prerequisites

- A VPS or dedicated server (tested on netcup VPS 500 G10s)
- A domain name for SSL certificates (optional but recommended)
- SSH access to the target server
- Nix package manager installed locally

## 🚀 Quick Start

### Option 1: Fresh Server Deployment (Recommended)

If you have a fresh server with any Linux distribution, you can use nixos-anywhere to automatically install NixOS and deploy the infrastructure:

1. **Set up SSH access** to your server:
   ```bash
   ssh-copy-id -o PubkeyAuthentication=no -o PreferredAuthentications=password root@YOUR_SERVER_IP
   ```

2. **Deploy with nixos-anywhere**:
   ```bash
   nix run github:numtide/nixos-anywhere -- --flake .\#pretix-server-01 root@YOUR_SERVER_IP
   ```

### Option 2: Existing NixOS Server

If you already have a NixOS server, deploy with:

```bash
nixos-rebuild switch --flake '.#pretix-server-01' --target-host root@YOUR_SERVER_IP --build-host root@YOUR_SERVER_IP
```

## ⚙️ Configuration

### 1. Domain Setup (Optional but Recommended)

For SSL certificates and professional URLs, configure DNS records for your domain:

```
tickets.your-domain.com       → YOUR_SERVER_IP
schwarmplaner.your-domain.com → YOUR_SERVER_IP
api.your-domain.com          → YOUR_SERVER_IP
grafana.your-domain.com      → YOUR_SERVER_IP
```

### 2. Secrets Configuration

Configure secrets for all services using sops-nix:

```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

The secrets file includes:
- **Pretix**: Email configuration and database settings  
- **Schwarmplaner**: Database and API authentication
- **Bank Automation**: Banking API credentials
- **Backup**: Remote storage credentials and encryption keys

### 3. Service Configuration

Edit `configuration.nix` to customize:
- Service hostnames and ports
- SSL certificate email addresses
- Enable/disable specific services
- Resource allocation and scaling

## 🌐 Service Access

After deployment, the following services will be available:

| Service | URL | Description |
|---------|-----|-------------|
| **Pretix (Ticketing)** | `https://tickets.your-domain.com` | Event ticket sales and management |
| **Schwarmplaner** | `https://schwarmplaner.your-domain.com` | Volunteer shift planning interface |
| **Schwarmplaner API** | `https://api.your-domain.com` | REST API for volunteer management |
| **Grafana** | `https://grafana.your-domain.com` | Monitoring dashboards |

> **Note**: Replace `your-domain.com` with your actual domain. Without custom domains, services will be available on their respective ports.

## 📊 Monitoring & Observability

### Basic Setup (Local Access)
```nix
services.monitoring.enable = true;
```

Access via server IP:
- **Grafana**: `http://YOUR_SERVER_IP:3000` (admin/admin)
- **Prometheus**: `http://YOUR_SERVER_IP:9090`
- **Loki**: `http://YOUR_SERVER_IP:3100`

### Advanced Setup (Custom Domains)
```nix
services.monitoring = {
  enable = true;
  grafanaHost = "grafana.your-domain.com";
  prometheusHost = "prometheus.your-domain.com";
  lokiHost = "loki.your-domain.com";
  acmeMail = "admin@your-domain.com";
};
```

### Monitoring Features
- **📈 System Metrics**: CPU, memory, disk, network statistics
- **📋 Service Health**: Application status and performance monitoring  
- **📝 Log Aggregation**: Centralized logging with search and filtering
- **🚨 Alerting**: Configurable alerts for system and service issues
- **🔒 SSL/TLS**: Automatic HTTPS certificates for all monitoring endpoints

## 🔧 Development & Maintenance

### Updating the System

1. **Update flake dependencies**:
   ```bash
   nix flake update
   ```

2. **Deploy updates**:
   ```bash
   nixos-rebuild switch --flake '.#pretix-server-01' --target-host root@YOUR_SERVER_IP --build-host root@YOUR_SERVER_IP
   ```

### Backup Management

The system includes automated backup with:
- **Encrypted backups** of all service data
- **Remote storage** support (S3, rsync, etc.)
- **Restoration scripts** for disaster recovery
- **Configurable schedules** for different data types

Access backup tools:
```bash
# View backup status
systemctl status backup.service

# Manual backup
systemctl start backup.service

# Restore from backup
/scripts/backup-restore.sh
```

### Adding Custom Services

1. **Create a new module** in `modules/your-service/default.nix`
2. **Add configuration** to `configuration.nix`
3. **Update secrets** if needed in `secrets/secrets.yaml`
4. **Deploy** the changes

## 🏗 Architecture

### System Design
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Internet      │    │   Nginx Proxy    │    │   Services      │
│                 │────│  (SSL/TLS)       │────│                 │
│  Users/Clients  │    │  Port 80/443     │    │  Various Ports  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Monitoring    │
                       │  Grafana/Loki   │
                       │   Prometheus    │
                       └─────────────────┘
```

### Service Dependencies
- **Pretix**: PostgreSQL database, Redis cache, file storage
- **Schwarmplaner**: MySQL database, API backend, frontend
- **Monitoring**: System metrics, log collection, dashboards

### Data Flow
1. **User requests** → Nginx reverse proxy
2. **SSL termination** → Service routing
3. **Application processing** → Database/storage operations  
4. **Monitoring collection** → Metrics and logs aggregation
5. **Backup operations** → Encrypted remote storage

## 🔒 Security

### Built-in Security Features
- **Automatic SSL/TLS** certificates via Let's Encrypt
- **Encrypted secrets** management with sops-nix
- **Isolated services** with proper network segmentation
- **Regular security updates** via NixOS channels
- **Backup encryption** for data protection

### Security Best Practices
- Change default passwords after deployment
- Use strong encryption keys for secrets
- Regularly update the system and dependencies
- Monitor access logs and system metrics
- Implement proper firewall rules
- Use SSH key-based authentication only

## 🤝 Contributing

We welcome contributions! Please see our contribution guidelines:

1. **Fork the repository** and create a feature branch
2. **Test your changes** in a development environment
3. **Update documentation** for any new features
4. **Submit a pull request** with a clear description

### Development Environment
```bash
# Clone the repository
git clone https://github.com/zugvoegel-festival/ticketing.git
cd ticketing

# Start a development shell
nix develop

# Test deployment locally
nixos-rebuild build --flake '.#pretix-server-01'
```

## 📚 Documentation

- **[NixOS Manual](https://nixos.org/manual/nixos/stable/)**: Official NixOS documentation
- **[Nix Flakes](https://nixos.wiki/wiki/Flakes)**: Modern Nix package management
- **[sops-nix](https://github.com/Mic92/sops-nix)**: Secrets management
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)**: Remote NixOS installation

### Service Documentation
- **[Pretix Docs](https://docs.pretix.eu/)**: Ticketing system administration
- **[Grafana Docs](https://grafana.com/docs/)**: Monitoring and dashboards

## 🐛 Troubleshooting

### Common Issues

**SSL Certificate Generation Fails**
- Verify DNS records point to your server
- Check firewall allows ports 80 and 443
- Ensure email address is valid for Let's Encrypt

**Service Won't Start**
- Check logs: `journalctl -u service-name -f`
- Verify secrets are properly configured
- Ensure required ports are not in use

**Backup Failures**
- Check remote storage credentials
- Verify network connectivity to backup destination
- Review backup service logs

**Performance Issues**
- Monitor resource usage via Grafana
- Check database performance metrics
- Review application logs for errors

### Getting Help
- **Issues**: Open an issue on GitHub with detailed logs
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Email security@zugvoegelfestival.org for vulnerabilities

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[Pretix](https://pretix.eu/)** team for the excellent ticketing platform
- **[NixOS](https://nixos.org/)** community for the reliable infrastructure foundation
- **[Zugvögel Festival](https://zugvoegelfestival.org)** for supporting open-source event management tools

---

**Made with ❤️ for the event management community**