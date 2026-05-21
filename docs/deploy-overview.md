# Deploy overview (NixOS host + Pretix CI)

Short SSOT for how the **ticketing** repo deploys `pretix-server-01` (`185.232.69.172`).
Operator checklist: [`runbook.md`](runbook.md).

## Architecture

| Repo | Owns |
|------|------|
| **ticketing** (this repo) | NixOS flake, `environments/*.nix` image pins, host deploy scripts |
| **zugvoegel-festival/pretix** | App + `docker-build.yml` / `deploy.yml` / `rollback.yml` |
| **schwarmplaner** | App + `build.yml` / `deploy.yml` / `rollback.yml` |
| **99trees** | App + CI (production only) |

**App releases (Docker)** do not run `nixos-rebuild` from CI. Actions SSH as `deploy`, back up data, and run `<app>-restart-container <env> <tag>` (writes `/var/lib/<app>/deploy/<env>-image`, `docker pull`, `docker run`).

**Two image truths:**

| Layer | Location | Updated by |
|-------|----------|------------|
| Git SSOT | `environments/*.nix` → `app-image` / `pretixImage` | Release scripts, PR review |
| Runtime SSOT | `/var/lib/<app>/deploy/<env>-image` (tag only) | CI deploy/rollback; reconciled on `./deploy.sh` if missing/stale |

**Host / module changes** (nginx, monitoring, secrets, nixpkgs, image pins in Nix) are deployed manually:

```bash
./deploy.sh              # pinned flake only (nix run .#nixos-rebuild -- --fast; safe from macOS)
./deploy.sh --boot       # when switch hangs — activate on reboot
./update-and-deploy.sh   # nix flake update + deploy
```

## Host deploy cadence

| When | Command |
|------|---------|
| Infra / module PR merged | `./deploy.sh` |
| Monthly maintenance or security nixpkgs update | `./update-and-deploy.sh` |

Weekly automation opens a PR bumping `flake.lock` (`.github/workflows/flake-update.yml`). **Merge does not deploy** — apply on host during the monthly window (or sooner for security).

## Image pins

Instance pins live in `environments/`:

| File | Service |
|------|---------|
| `environments/pretix.nix` | Pretix (`manulinger/zv-ticketing`) |
| `environments/schwarmplaner-prod.nix` | Schwarmplaner production (single instance) |
| `environments/99trees-prod.nix` | 99trees production only |

App release scripts in **pretix** / **schwarmplaner** / **99trees** commit+push pin updates to this repo (`TICKETING_REPO`, default `../ticketing`).

## Pretix release flow

1. From **pretix** repo: `bash .cursor/skills/release/scripts/release-prod.sh [VERSION]` — pins `environments/pretix.nix`, pushes tag `vX.Y.Z`.
2. `docker-build.yml` builds → pushes `:X.Y.Z` + `:pretix-latest`.
3. `deploy.yml` backs up, runs `pretix-restart-container prod <tag>`, checks HTTPS.

Rollback: pretix repo Actions → *Rollback Docker image* → enter immutable tag.

## CI/CD (this repo)

| Workflow | Purpose |
|----------|---------|
| `flake-update.yml` | Weekly nixpkgs lock PR |

Pretix / Schwarmplaner / 99trees CI lives in their app repos. See pretix `DEPLOYMENT.md`.

## One-time setup

After adding `deployAuthorizedKeys` for pretix (and app repos), run once:

```bash
./deploy.sh
```

See pretix / schwarmplaner / 99trees `DEPLOYMENT.md` for app-specific secrets and health URLs.
