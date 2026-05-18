# Design

## Module shape

- Standard args: `{ config, lib, pkgs, ... }`; bind `let cfg = config.zugvoegel.services.<name>; in`.
- Options in `options.zugvoegel.services.<name>`; system config gated with `config = mkIf cfg.enable { … };`.
- Match naming and style of neighboring modules (pretix, schwarmplaner).

## Secrets

- One sops secret per env file (e.g. `pretix-envfile`, `schwarmplaner-prod-envfile`).
- Reference via `config.sops.secrets.<name>.path` in systemd/Docker config.

## Docker services

- Use `virtualisation.oci-containers` with dedicated bridge networks per app family.
- Per-instance data under `/var/lib/<app>-<instance>/`; pre-deploy backups via scoped helper scripts on PATH.

## nginx

- Virtual hosts defined in modules when `host` option is set; proxy to localhost service port.
- ACME email from module or host config.

## Documentation layers

- Commands/invariants → `AGENTS.md`
- Per-module options and files → `modules/<name>/README.md`
- Cross-module architecture → `.vibe/docs/`
- Human backup/restore procedures → `docs/BACKUP.md`

## Quality attributes

- **Reproducibility:** flake-pinned inputs, declarative host config.
- **Security:** encrypted secrets, least-privilege deploy user, TLS by default for public hosts.
- **Operability:** restic timers, monitoring stack, deploy scripts at repo root.
