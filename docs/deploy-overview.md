# Deploy overview (NixOS host + Pretix CI)

Short SSOT for how the **ticketing** repo deploys `pretix-server-01` (`185.232.69.172`).
Operator checklist: [`runbook.md`](runbook.md).

## Architecture

| Repo | Owns |
|------|------|
| **ticketing** (this repo) | NixOS flake, `environments/*.nix` image pins, host deploy scripts, Pretix Docker CI |
| **schwarmplaner** | App + `build.yml` / `deploy.yml` / `rollback.yml` |
| **99trees** | App + CI (production only) |
| **zugvoegel-festival/pretix** | Pretix Dockerfile source (built by `pretix-build.yml` here) |

**App releases (Docker)** do not run `nixos-rebuild` from CI. Actions SSH as `deploy`, back up data, and run `<app>-restart-container <env> <tag>` (writes `/var/lib/<app>/deploy/<env>-image`, `docker pull`, `docker run`).

**Two image truths:**

| Layer | Location | Updated by |
|-------|----------|------------|
| Git SSOT | `environments/*.nix` → `app-image` / `pretixImage` | Release scripts, PR review |
| Runtime SSOT | `/var/lib/<app>/deploy/<env>-image` (tag only) | CI deploy/rollback; reconciled on `./deploy.sh` if missing/stale |

**Host / module changes** (nginx, monitoring, secrets, nixpkgs, image pins in Nix) are deployed manually:

```bash
./deploy.sh              # pinned flake only
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
| `environments/schwarmplaner-prod.nix` | Schwarmplaner production |
| `environments/schwarmplaner-test.nix` | Schwarmplaner test |
| `environments/99trees-prod.nix` | 99trees production only |

App release scripts in **schwarmplaner** / **99trees** commit+push pin updates to this repo (`TICKETING_REPO`, default `../ticketing`).

## Pretix release flow

1. Update `environments/pretix.nix` with the target immutable tag (or let CI derive from tag).
2. Create and push tag `pretix-vX.Y.Z` on **this repo**.
3. `pretix-build.yml` builds from `zugvoegel-festival/pretix@main` → pushes `:X.Y.Z` + `:pretix-latest`.
4. `pretix-deploy.yml` backs up, runs `pretix-restart-container prod <tag>`, checks HTTPS.

Rollback: Actions → *Rollback Pretix Docker image* → enter immutable tag.

## CI/CD (this repo)

| Workflow | Purpose |
|----------|---------|
| `flake-update.yml` | Weekly nixpkgs lock PR |
| `pretix-build.yml` | Build + push Pretix image on `pretix-v*.*.*` tags |
| `pretix-deploy.yml` | SSH deploy after build |
| `pretix-rollback.yml` | Manual Pretix image rollback |

## GitHub Actions secrets (ticketing repo)

| Secret | Description |
|--------|-------------|
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` | Docker Hub push for Pretix builds |
| `SSH_PRIVATE_KEY` | Matches `deployAuthorizedKeys` in pretix module |
| `SSH_HOST` | (Optional) default `185.232.69.172` |
| `SSH_KNOWN_HOSTS` | **Required** for pretix deploy/rollback — `ssh-keyscan -H 185.232.69.172` |

## One-time setup

After adding `deployAuthorizedKeys` for pretix (and app repos), run once:

```bash
./deploy.sh
```

See schwarmplaner / 99trees `DEPLOYMENT.md` for app-specific secrets and health URLs.
