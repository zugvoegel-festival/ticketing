# Dependency graph

```
flake.nix
  └── configuration.nix
        ├── modules/pretix ──────────► sops, nginx, docker
        ├── modules/schwarmplaner ───► sops, nginx, docker, deploy user
        ├── modules/99trees ───────► sops, nginx, docker, deploy user
        ├── modules/wedding-catcher ► sops, nginx, docker
        ├── modules/bank-automation ► sops, bank-automation flake input
        ├── modules/monitoring ─────► nginx (optional), local data dirs
        └── modules/backup ──────────► sops, restic ◄── paths from all services

secrets/secrets.yaml ──► sops-nix ──► env files for all modules above
nginx ◄── vhost fragments merged from service modules
```

**Host deploy:** `./deploy.sh` / `./update-and-deploy.sh` → `nixos-rebuild switch` on `pretix-server-01`.

**CI deploy:** GitHub Actions → SSH as `deploy` → docker pull + systemctl restart (Schwarmplaner, 99trees); optional `*-deploy-backup` before restart.
