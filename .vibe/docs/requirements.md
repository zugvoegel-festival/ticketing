# Requirements

## REQ-INFRA-001 Service namespace

The system SHALL expose all festival services under `config.zugvoegel.services.<name>` with an `enable` option per module.

## REQ-INFRA-002 Secrets

The system SHALL store runtime secrets encrypted in `secrets/secrets.yaml` and mount them at `/run/secrets/` via sops-nix. Plaintext secrets SHALL NOT be committed.

## REQ-INFRA-003 HTTPS

When a service defines a public host, the system SHALL terminate TLS via nginx with ACME certificate renewal.

## REQ-INFRA-004 Backup

When backup is enabled for a service, the system SHALL schedule restic jobs to `${s3BaseUrl}/${bucketPrefix}-${serviceName}` using shared backup credentials.

## REQ-INFRA-005 CI deploy

Schwarmplaner and 99trees CI SHALL deploy via the unprivileged `deploy` user with sudo limited to explicit docker/systemctl/backup commands — not root SSH.

## REQ-INFRA-006 Module discovery

New modules SHALL be addable as `modules/<name>/default.nix` without editing `flake.nix` module lists manually.

## REQ-INFRA-007 Reproducibility

Host configuration SHALL be buildable via `nixos-rebuild build --flake '.#pretix-server-01'` from this checkout.
