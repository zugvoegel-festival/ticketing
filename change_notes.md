## 🎉 What's New
- 

## 🐛 Bug Fixes
- 

## 🔧 Improvements
- Monitoring: bind Grafana/Loki/Prometheus/Promtail to localhost, SOPS Grafana admin password, security headers on nginx vhosts, openFirewall default false.
- Backup: prefer dbPasswordFile over dbPassword for MySQL dumps (keeps passwords out of the Nix store).
- Pretix: gate nuke-docker behind enableDangerousMaintenanceTools; Postgres auth via sops envfile.

## 📚 Documentation
- 

## ⚠️ Breaking Changes
- 
