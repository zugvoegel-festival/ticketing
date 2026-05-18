# Monitoring

**Purpose:** Grafana, Loki, Prometheus, and Promtail stack with optional nginx TLS frontends.

- `default.nix` — `zugvoegel.services.monitoring` options, systemd services, nginx vhosts when hosts set
- `dashboards/` — bundled Grafana JSON dashboards (system logs, Docker health, server essentials)

**Depends on:** nginx (when public hosts configured), local filesystem for Loki/Prometheus data.
