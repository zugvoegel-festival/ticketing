# Ticketing Deployment using Pretix on NixOS

The following was tested on [netcup](https://netcup.de) using a `VPS 500 G10s`
server. Other providers or server variants will probably work too, but are
untested at this point.

This deployment includes:
- **Pretix**: Event ticketing system
- **Vikunja**: Task management and project organization
- **Schwarmplaner**: Volunteer shift planning system
- **Audio Transcriber**: Audio transcription service
- **MinIO**: S3-compatible object storage
- **Bank Automation**: Automated bank transaction processing
- **Automated Backup**: Regular backups of all services
- **Monitoring Stack**: Simplified monitoring with Loki (logs), Grafana (dashboards), Prometheus (metrics), and Promtail (log collection) - supports both local access and custom domains with SSL

After booking the `VPS 500 G10s` you will get an e-mail with the root
credentials and a `debian-minimal` image preinstalled. 

### Initial deployment (Server is still other OS)

Setup public-key based authentication on the server and run nixos-anywhere for
intial deployment. The public key will persist after infection.

```
ssh-copy-id -o PubkeyAuthentication=no -o PreferredAuthentications=password  root@185.232.69.172
ssh root@185.232.69.172
nix run github:numtide/nixos-anywhere -- --flake .\#pretix-server-01 root@185.232.69.172
```

### Further deployments (Server is NixOS)

You now have a NixOS server and can deploy this demo. You might want to set DNS
records if you have a domain and configure the nginx virtual host accordingly,
otherwise deployment will still work, but you won't get SSL certificates
generated as the DNS challenge will fail.

Further deployments can be done with:

```sh
nix-shell -p nixos-rebuild 

nixos-rebuild switch --flake '.#pretix-server-01' --target-host root@185.232.69.172  --build-host root@185.232.69.172 
```

Note: Other deployment methods are possible and might be more suitable for
multiple servers.
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) is used here
for simplicity. Other options are using a deployment tool like
[lollypops](https://github.com/pinpox/lollypops) or uploading a pre-backed
`.qcow2` image, which can be generated from a flake.

### Secrets management

Secrets are encrypted and managed with [sops-nix](https://github.com/Mic92/sops-nix)

```sh
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

The secrets file includes configuration for all services:
- MinIO root credentials (`minio-envfile`)
- Pretix email configuration (`pretix-envfile`)
- Vikunja mailer settings (`vikunja-envfile`)
- Schwarmplaner database and API settings (`schwarm-db-envfile`, `schwarm-api-envfile`)
- Audio transcriber configuration (`audiotranscriber-envfile`)
- Bank automation credentials (`bank-envfile`)
- Backup service credentials (`backup-envfile`, `backup-passwordfile`)

### Services and URLs

Once deployed, the following services will be available:

- **Pretix (Ticketing)**: https://tickets.zugvoegelfestival.org
- **Schwarmplaner (Volunteer Management)**: https://schwarmplaner.zugvoegelfestival.org
- **Schwarmplaner API**: https://api.zugvoegelfestival.org
- **Audio Transcriber**: https://audiotranscriber.loco.vision
- **Vikunja (Task Management)**: https://brett.feuersalamander-nippes.de
- **MinIO S3 API**: https://minio.zugvoegelfestival.org
- **MinIO Console**: https://minio-console.zugvoegelfestival.org

### Monitoring Services

The simplified monitoring stack provides essential observability with minimal configuration:

**Basic Configuration (Local Access):**
```nix
services.monitoring = {
  enable = true;  # Enables all monitoring services
};
```
- **Grafana Dashboard**: http://[server-ip]:3000 (admin/admin)
- **Prometheus Metrics**: http://[server-ip]:9090
- **Loki Logs**: http://[server-ip]:3100

**Advanced Configuration (With Custom Domains):**
```nix
services.monitoring = {
  enable = true;
  grafanaHost = "grafana.example.com";
  prometheusHost = "prometheus.example.com";
  lokiHost = "loki.example.com";
  acmeMail = "admin@example.com";  # For SSL certificates
};
```
- **Grafana Dashboard**: https://grafana.example.com (admin/admin)
- **Prometheus Metrics**: https://prometheus.example.com
- **Loki Logs**: https://loki.example.com

**Features:**
- **Loki**: Log aggregation with basic filesystem storage
- **Grafana**: Dashboard visualization with Loki and Prometheus datasources
- **Prometheus**: Basic metrics collection from monitoring services
- **Promtail**: System journal log collection via systemd
- **SSL/TLS**: Automatic HTTPS certificates via Let's Encrypt (when hosts configured)
- **Nginx Reverse Proxy**: Automatic setup for custom domains

### Flake Updates

To update the dependencies in the flake:

```sh
nix flake update
```

This will update all inputs to their latest versions according to the flake.lock file.