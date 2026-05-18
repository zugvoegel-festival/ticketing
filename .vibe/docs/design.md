# Design

## Module shape

- Standard args: `{ config, lib, pkgs, ... }`; bind `let cfg = config.zugvoegel.services.<name>; in`.
- Options in `options.zugvoegel.services.<name>`; system config gated with `config = mkIf cfg.enable { … };`.
- Follow patterns of pretix (single stack) or schwarmplaner/99trees (multi-instance + CI).

## Secrets

- One sops env file per service or instance (e.g. `pretix-envfile`, `99trees-prod-envfile`).
- Mount via `config.sops.secrets.<name>.path` in Docker/systemd config.

## Docker services

- `virtualisation.oci-containers` with per-app bridge networks (`pretix-net`, `schwarmplaner-net`, `99trees-net`).
- Data under `/var/lib/<app>-<instance>/`; init units create dirs before container start.

## CI deploy pattern

- Shared `deploy` user receives `deployAuthorizedKeys` from Schwarmplaner and 99trees modules.
- Scoped sudo for docker pull, systemctl restart, and `*-deploy-backup` helpers only.

## nginx

- Virtual hosts when `host` set; proxy to localhost port; security headers on public locations; ACME from module or host config.

## Documentation layers

- Commands/invariants → `AGENTS.md`
- Per-module files and options → `modules/<name>/README.md`
- Cross-module architecture → `.vibe/docs/`
- Human backup/restore → `docs/BACKUP.md`

## Quality attributes

- **Reproducibility:** flake-pinned inputs, declarative host config.
- **Security:** encrypted secrets (prefer file paths over Nix store copies), least-privilege deploy user, TLS + nginx security headers, monitoring on 127.0.0.1 by default.
- **Operability:** restic timers, monitoring dashboards, `./deploy.sh` at repo root.
