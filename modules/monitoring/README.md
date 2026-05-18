# Monitoring

**Purpose:** Grafana, Loki, Prometheus, and Alloy (journal → Loki) bound to localhost with optional nginx TLS frontends.

- `default.nix` — `zugvoegel.services.monitoring` options; stack listens on 127.0.0.1; Grafana admin password via sops `grafana-admin-password`; `openFirewall` defaults false; optional nginx vhosts with security headers
- `dashboards/` — bundled Grafana JSON dashboards (system logs, Docker health, server essentials)

**Depends on:** nginx (when public hosts configured), local filesystem for Loki/Prometheus data.
