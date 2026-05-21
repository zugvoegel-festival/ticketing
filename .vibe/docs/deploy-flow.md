# Deploy flow

## Host config deploy (NixOS)

1. Developer runs `./deploy.sh` (pinned lock; `--boot` if switch inhibited) or `./update-and-deploy.sh` (flake update + deploy).
2. `nixos-rebuild switch --flake '.#pretix-server-01'` applies `configuration.nix`, `environments/*.nix` pins, and all enabled modules.
3. sops-nix decrypts secrets; systemd/Docker units start or restart affected services.
4. nginx picks up new vhost fragments; ACME renews certs as needed.

## CI app deploy (Pretix / Schwarmplaner / 99trees)

1. GitHub Actions SSH as unprivileged `deploy` user (keys from each service's `deployAuthorizedKeys` in `configuration.nix`).
2. Optional pre-deploy backup: `pretix-deploy-backup [label]`, `schwarmplaner-deploy-backup prod [label]`, or `99trees-deploy-backup prod [label]`.
3. `<app>-restart-container <env> <tag>` writes `/var/lib/<app>/deploy/<env>-image`, pulls the image, recreates the container with the baked run spec (not `oci-containers` for app images).
4. nginx already proxies public host to localhost port — no host rebuild required for image-only updates.

On `./deploy.sh`, activation scripts reconcile runtime tag files from `environments/*.nix` when missing or stale (does not auto-restart running containers).

Pretix / Schwarmplaner / 99trees build/deploy workflows live in their app repos. Image pins are committed to `environments/*.nix` (app release scripts).

## Backup side path

Restic timers (backup module) run independently on schedule; data paths declared per service in `configuration.nix`.
