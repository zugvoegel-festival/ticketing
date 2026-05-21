## 🎉 What's New
- 

## 🐛 Bug Fixes
- 

## 🔧 Improvements
- Extract app image pins to `environments/`; centralize shared `deploy` user in `configuration.nix`; pin nixpkgs to `nixos-25.05`; add Pretix CI deploy wiring (`deployAuthorizedKeys`, `pretix-deploy-backup`); `deploy.sh` supports `--boot`/`--switch`.
- Remove unused `trees99-test` restic job (99trees is prod-only); flake imports only directories under `modules/`.
- Remove responsible-vibe MCP config; pin GitHub Actions checkout and install-nix to commit SHAs; fix nixos-anywhere flake target to pretix-server-01.

## 📚 Documentation
- Update AGENTS.md, pretix module README, and deploy-flow for environment pins and Pretix CI deploy.
- Sync monitoring docs for Alloy (module README, architecture, index).
- Align 99trees secrets README with prod-only deployment, `trees.loco.vision`, and B2 bucket name.
- Sync module READMEs and .vibe/docs for infra hardening (localhost monitoring, security headers, dbPasswordFile); add deploy-flow.md; adapt docs-shared reference for NixOS layout.

## ⚠️ Breaking Changes
- Monitoring option `promtailPort` renamed to `alloyPort` (Promtail removed).
