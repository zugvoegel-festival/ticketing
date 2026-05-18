# Requirements

## REQ-INFRA-001 Service namespace

The system SHALL expose all festival services under `config.zugvoegel.services.<name>` with an `enable` option per module.

## REQ-INFRA-002 Secrets

The system SHALL store runtime secrets encrypted in `secrets/secrets.yaml` and mount them at `/run/secrets/` via sops-nix. Plaintext secrets SHALL NOT be committed.

## REQ-INFRA-003 HTTPS

When a module defines a public host, the system SHALL terminate TLS via nginx with ACME certificate renewal.

## REQ-INFRA-004 Backup

When backup is enabled for a service, the system SHALL schedule restic jobs using shared `backup-envfile` / `backup-passwordfile` credentials and expose a `backup-restore` helper on PATH.

## REQ-INFRA-005 CI deploy

Schwarmplaner and 99trees CI SHALL deploy via the unprivileged `deploy` user with sudo limited to explicit docker, systemctl, and backup commands — not root SSH.

## REQ-INFRA-006 Module discovery

New modules SHALL be addable as `modules/<name>/default.nix` without manually listing them in `flake.nix`.

## REQ-INFRA-007 Multi-instance apps

Schwarmplaner and 99trees SHALL support per-instance Docker stacks with dedicated data dirs, sops env secrets, and nginx vhosts.

## REQ-INFRA-008 Reproducibility

Host configuration SHALL be buildable via `nixos-rebuild build --flake '.#pretix-server-01'` from this checkout.

## REQ-INFRA-009 Observability exposure

The monitoring stack SHALL bind services to 127.0.0.1 by default; public access SHALL go through nginx TLS with `openFirewall` false unless explicitly enabled.
