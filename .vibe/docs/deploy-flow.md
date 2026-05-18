# Deploy flow

## Host config deploy (NixOS)

1. Developer runs `./deploy.sh` (current lock) or `./update-and-deploy.sh` (flake update + deploy).
2. `nixos-rebuild switch --flake '.#pretix-server-01'` applies `configuration.nix` and all enabled modules.
3. sops-nix decrypts secrets; systemd/Docker units start or restart affected services.
4. nginx picks up new vhost fragments; ACME renews certs as needed.

## CI app deploy (Schwarmplaner / 99trees)

1. GitHub Actions SSH as unprivileged `deploy` user (keys from `deployAuthorizedKeys`).
2. Optional: run `schwarmplaner-deploy-backup` or `99trees-deploy-backup` for consistent SQLite snapshot.
3. `docker pull` new image tag; `systemctl restart docker-<app>-<instance>.service`.
4. nginx already proxies public host to localhost port — no host rebuild required for image-only updates.

## Backup side path

Restic timers (backup module) run independently on schedule; data paths declared per service in `configuration.nix`.
