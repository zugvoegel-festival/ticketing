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

Use `./update-and-deploy.sh` when bumping `flake.lock` (nixpkgs on `nixos-25.05`).

## App releases (no nixos-rebuild)

| App | Tag / trigger | Git pin | Runtime file | Restart command |
|-----|----------------|---------|----------------|-----------------|
| Pretix | `pretix-v*.*.*` in **ticketing** | `environments/pretix.nix` | `/var/lib/pretix/deploy/prod-image` | `pretix-restart-container prod [tag]` |
| Schwarmplaner | `v*.*.*` / `test-*` in **schwarmplaner** | `environments/schwarmplaner-{prod,test}.nix` | `/var/lib/schwarmplaner/deploy/<env>-image` | `schwarmplaner-restart-container <env> [tag]` |
| 99trees | `v*.*.*` in **99trees** (prod only) | `environments/99trees-prod.nix` | `/var/lib/99trees/deploy/prod-image` | `99trees-restart-container prod [tag]` |

Schwarmplaner / 99trees release scripts commit pin updates here (`TICKETING_REPO` in app repos). CI passes the tag to the restart script; `./deploy.sh` reconciles runtime files from Git when they drift.

## Pretix release

1. Set `pretixImage` in `environments/pretix.nix` to the target immutable tag (or rely on tag + CI).
2. Push `pretix-vX.Y.Z` on this repo → `pretix-build.yml` → `pretix-deploy.yml`.
3. Rollback: Actions → *Rollback Pretix Docker image*.

## Monthly nixpkgs

Merge PR from `flake-update.yml`, then on host:

```bash
./update-and-deploy.sh
```

## Required GitHub secrets (this repo)

| Secret | Notes |
|--------|--------|
| `SSH_KNOWN_HOSTS` | `ssh-keyscan -H 185.232.69.172` — **required** for pretix deploy/rollback |
| `SSH_PRIVATE_KEY` | Pretix deploy user |
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` | Pretix image push |

App repos carry their own `SSH_*` secrets for schwarmplaner / 99trees workflows.
