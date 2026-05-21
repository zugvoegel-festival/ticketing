## 🎉 What's New
- Pretix Docker build/deploy/rollback GitHub Actions and weekly flake-update PR workflow.
- Runtime container image pins: `<app>-restart-container` scripts, `/var/lib/<app>/deploy/<env>-image`, activation sync from `environments/*.nix`.

## 🐛 Bug Fixes
- Quote `EXTRA_RUN_ARGS` in restart scripts so Pretix `-v …pretix.cfg` volume mounts work under systemd.
- App CI deploys no longer restart `oci-containers` units with a stale Nix-baked image tag after `docker pull`.
- Remove Schwarmplaner test instance (no DNS/stage); fixes ACME NXDOMAIN and missing `test-latest` image pull.
- Drop obsolete `legacy_position` from Alloy journal config (Alloy 1.8 on nixos-25.05).

## 🔧 Improvements
- Pin Pretix Git SSOT to `manulinger/zv-ticketing:pretix` until pretix-v* CI tags are routine.
- `deploy.sh` uses flake app `nix run .#nixos-rebuild -- --fast` so host deploy works from macOS (Vocura pattern); `update-and-deploy.sh` delegates to `deploy.sh`.
- Extract app image pins to `environments/`; centralize shared `deploy` user in `configuration.nix`; pin nixpkgs to `nixos-25.05`; add Pretix CI deploy wiring (`deployAuthorizedKeys`, `pretix-deploy-backup`); `deploy.sh` supports `--boot`/`--switch`.
- Remove unused `trees99-test` restic job (99trees is prod-only); flake imports only directories under `modules/`.
- Remove responsible-vibe MCP config; pin GitHub Actions checkout and install-nix to commit SHAs; fix nixos-anywhere flake target to pretix-server-01.

## 📚 Documentation
- Runbook/deploy-overview: macOS deploy via `--fast`, `--boot` when switch stalls during major unit changes.
- Update AGENTS.md, deploy overview/runbook, HANDOVER, and deploy-flow for runtime image pins and restart scripts.
- Update AGENTS.md, pretix module README, and deploy-flow for environment pins and Pretix CI deploy.
- Sync monitoring docs for Alloy (module README, architecture, index).
- Align 99trees secrets README with prod-only deployment, `trees.loco.vision`, and B2 bucket name.
- Sync module READMEs and .vibe/docs for infra hardening (localhost monitoring, security headers, dbPasswordFile); add deploy-flow.md; adapt docs-shared reference for NixOS layout.

## ⚠️ Breaking Changes
- App containers no longer use `docker-<app>-<env>.service` from `oci-containers`; CI must call `<app>-restart-container` (schwarmplaner/99trees app repos).
- Monitoring option `promtailPort` renamed to `alloyPort` (Promtail removed).
