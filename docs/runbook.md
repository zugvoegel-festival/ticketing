# Operator runbook (pretix-server-01)

Host: **pretix-server-01** (`185.232.69.172`). Architecture and CI tables:
[`deploy-overview.md`](deploy-overview.md).

## First-time host activation

1. Add deploy pubkeys in `configuration.nix` (`deployAuthorizedKeys` per service).
2. Ensure SOPS secrets and DNS are ready (see `secrets/README.md`).
3. From this repo:

```bash
./deploy.sh
```

Deploy from **macOS** uses `nix run .#nixos-rebuild -- --fast` (flake app; do not use `nix-shell -p nixos-rebuild`).

If `switch` hangs or D-Bus disconnects during activation (e.g. first rollout of runtime image pins), use boot instead of switch:

```bash
./deploy.sh --boot
# then reboot pretix-server-01
```

Use `./update-and-deploy.sh` when bumping `flake.lock` (nixpkgs on `nixos-25.05`). Pass `--boot` through: `./update-and-deploy.sh --boot`.

## App releases (no nixos-rebuild)

| App | Tag / trigger | Git pin | Runtime file | Restart command |
|-----|----------------|---------|----------------|-----------------|
| Pretix | `v*.*.*` in **pretix** | `environments/pretix.nix` | `/var/lib/pretix/deploy/prod-image` | `pretix-restart-container prod [tag]` |
| Schwarmplaner | `v*.*.*` in **schwarmplaner** (prod only) | `environments/schwarmplaner-prod.nix` | `/var/lib/schwarmplaner/deploy/prod-image` | `schwarmplaner-restart-container prod [tag]` |
| 99trees | `v*.*.*` in **99trees** (prod only) | `environments/99trees-prod.nix` | `/var/lib/99trees/deploy/prod-image` | `99trees-restart-container prod [tag]` |

Pretix / Schwarmplaner / 99trees release scripts commit pin updates here (`TICKETING_REPO` in app repos). CI passes the tag to the restart script; `./deploy.sh` reconciles runtime files from Git when they drift.

## Pretix release

From the **pretix** repo:

```bash
bash .cursor/skills/release/scripts/release-prod.sh [VERSION]
```

Or push tag `vX.Y.Z` manually → `docker-build.yml` → `deploy.yml`. Rollback: pretix repo Actions → *Rollback Docker image*.

## Monthly nixpkgs

Merge PR from `flake-update.yml`, then on host:

```bash
./update-and-deploy.sh
```

## Required GitHub secrets

App repos (pretix, schwarmplaner, 99trees) carry their own `SSH_*` and `DOCKER_*` secrets. This repo has no app-deploy secrets.

## App CI migration (local clones)

Sibling repos: `/Users/manuel.huettel/Repos/privat/pretix`, `/Users/manuel.huettel/Repos/privat/schwarmplaner`, `/Users/manuel.huettel/Repos/privat/99trees`.

| App | Deploy SSH (after backup) | Rollback SSH |
|-----|---------------------------|--------------|
| Schwarmplaner prod | `sudo schwarmplaner-restart-container prod <tag>` | same with rollback tag |
| 99trees prod | `sudo 99trees-restart-container prod <tag>` | same |

No hosted Schwarmplaner test instance — remove test deploy/rollback jobs in schwarmplaner CI when merging.
