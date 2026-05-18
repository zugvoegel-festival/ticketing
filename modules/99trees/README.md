# 99trees

**Purpose:** Per-instance Docker stacks for the Zugvögel field game with nginx, deploy user, and pre-deploy backup script.

- `default.nix` — `zugvoegel.services.trees99` options, multi-instance containers, nginx vhosts with security headers, `99trees-deploy-backup`, shared `deploy` user sudo rules

**Depends on:** sops-nix (per-instance env secrets), nginx, Docker; shared `deploy` user (often from schwarmplaner).

**Used by:** `configuration.nix` (`prod` instance), GitHub Actions via `deployAuthorizedKeys`.
