# Dependency graph

```
flake.nix
  └── configuration.nix
        ├── modules/pretix ──► sops, nginx, docker
        ├── modules/schwarmplaner ──► sops, nginx, docker, deploy user
        ├── modules/99trees ──► sops, nginx, docker, deploy user
        ├── modules/wedding-catcher ──► sops, nginx, docker
        ├── modules/bank-automation ──► sops, bank-automation flake input
        ├── modules/monitoring ──► nginx (optional), local data dirs
        └── modules/backup ──► sops, restic ◄── data paths from all services

secrets/secrets.yaml ──► sops-nix ──► all modules needing env files
nginx (configuration.nix) ◄── vhost fragments from service modules
```

**Deploy flow:** `./deploy.sh` or `./update-and-deploy.sh` → `nixos-rebuild switch` on `pretix-server-01`.

**CI deploy flow:** GitHub Actions → SSH as `deploy` → docker pull / systemctl restart (Schwarmplaner, 99trees).
