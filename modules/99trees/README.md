# 99trees

**Purpose:** Production Docker stack for the Zugvögel field game with nginx, deploy user, and CI restart/backup scripts.

- `default.nix` — `zugvoegel.services.trees99` options, runtime container via `99trees-restart-container`, nginx vhosts with security headers, `99trees-deploy-backup prod [label]`

**Depends on:** sops-nix (`99trees-prod-envfile`), nginx, Docker, `lib/runtime-container.nix`; shared `deploy` user.

**Image pin:** `environments/99trees-prod.nix`. Runtime tag: `/var/lib/99trees/deploy/prod-image`.

**Used by:** `configuration.nix` (prod only), GitHub Actions via `deployAuthorizedKeys`.
