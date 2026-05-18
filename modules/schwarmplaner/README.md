# Schwarmplaner

**Purpose:** Per-instance Docker stacks for volunteer shift planning with nginx, deploy user, and CI deploy sudo rules.

- `default.nix` — `zugvoegel.services.schwarmplaner` options, multi-instance containers, nginx vhosts with security headers, `schwarmplaner-deploy-backup` helper, shared `deploy` user wiring

**Depends on:** sops-nix (per-instance env secrets), nginx, Docker.

**Used by:** `configuration.nix` (`prod` / `test` instances), GitHub Actions via unprivileged `deploy` SSH keys.
