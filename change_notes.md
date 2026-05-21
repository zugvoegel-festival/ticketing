## 🎉 What's New
- Move Pretix Docker build/deploy/rollback CI from ticketing to zugvoegel-festival/pretix (Schwarmplaner pattern).
- Weekly flake-update PR workflow for nixpkgs lock bumps.
- Runtime container image pins: `<app>-restart-container` scripts, `/var/lib/<app>/deploy/<env>-image`, activation sync from `environments/*.nix`.

## 🐛 Bug Fixes
- Align `backup-restore` S3 repository URL with restic module (`${bucketPrefix}-${service}`, not slash path).
- Quote `EXTRA_RUN_ARGS` in restart scripts so Pretix `-v …pretix.cfg` volume mounts work under systemd.
- App CI deploys no longer restart `oci-containers` units with a stale Nix-baked image tag after `docker pull`.
- Remove Schwarmplaner test instance (no DNS/stage); fixes ACME NXDOMAIN and missing `test-latest` image pull.
- Drop obsolete `legacy_position` from Alloy journal config (Alloy 1.8 on nixos-25.05).

## 🔧 Improvements
- Deploy-backup helpers accept `prod` only (Schwarmplaner and 99trees); remove legacy test-instance artifacts from host.
- `deploy.sh` uses flake app `nix run .#nixos-rebuild -- --fast` so host deploy works from macOS (Vocura pattern); `update-and-deploy.sh` delegates to `deploy.sh`.
- Extract app image pins to `environments/`; centralize shared `deploy` user in `configuration.nix`; pin nixpkgs to `nixos-25.05`; add Pretix CI deploy wiring (`deployAuthorizedKeys`, `pretix-deploy-backup`); `deploy.sh` supports `--boot`/`--switch`.
- Remove unused `trees99-test` restic job (99trees is prod-only); flake imports only directories under `modules/`.
- Remove responsible-vibe MCP config; pin GitHub Actions checkout and install-nix to commit SHAs; fix nixos-anywhere flake target to pretix-server-01.

## 📚 Documentation
- Align deploy, backup, module READMEs, and secrets docs for prod-only hosts, runtime image pins, and pretix-repo CI.

## ⚠️ Breaking Changes
- App containers no longer use `docker-<app>-<env>.service` from `oci-containers`; CI must call `<app>-restart-container` (schwarmplaner/99trees app repos).
- Monitoring option `promtailPort` renamed to `alloyPort` (Promtail removed).
