# Schwarmplaner

**Purpose:** Production Docker stack for volunteer shift planning with nginx, deploy user, and CI restart/backup scripts.

- `default.nix` — `zugvoegel.services.schwarmplaner` options, runtime container via `schwarmplaner-restart-container`, nginx vhosts with security headers, `schwarmplaner-deploy-backup prod [label]`

**Depends on:** sops-nix (`schwarmplaner-prod-envfile`), nginx, Docker, `lib/runtime-container.nix`.

**Image pin:** `environments/schwarmplaner-prod.nix`. Runtime tag: `/var/lib/schwarmplaner/deploy/prod-image`.

**Used by:** `configuration.nix` (prod only), GitHub Actions via `deployAuthorizedKeys`.
