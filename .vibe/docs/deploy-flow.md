# Deploy flow

## Host config deploy (NixOS)

1. Developer runs `./deploy.sh` (pinned lock; `--boot` if switch inhibited) or `./update-and-deploy.sh` (flake update + deploy).
2. `nixos-rebuild switch --flake '.#pretix-server-01'` applies `configuration.nix`, `environments/*.nix` pins, and all enabled modules.
3. sops-nix decrypts secrets; systemd/Docker units start or restart affected services.
4. nginx picks up new vhost fragments; ACME renews certs as needed.

## CI app deploy (Pretix / Schwarmplaner / 99trees)

1. GitHub Actions SSH as unprivileged `deploy` user (keys from each service's `deployAuthorizedKeys` in `configuration.nix`).
2. Optional pre-deploy backup: `pretix-deploy-backup`, `schwarmplaner-deploy-backup`, or `99trees-deploy-backup`.
3. `docker pull` immutable image tag; `systemctl restart docker-<app>-<instance>.service`.
4. nginx already proxies public host to localhost port — no host rebuild required for image-only updates.

Pretix build/deploy workflows live in this repo; Schwarmplaner and 99trees CI live in their app repos. Image pins are committed to `environments/*.nix` (app release scripts or Pretix tag CI).

## Backup side path

Restic timers (backup module) run independently on schedule; data paths declared per service in `configuration.nix`.
