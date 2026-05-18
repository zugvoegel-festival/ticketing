# Architecture

## Introduction and goals

NixOS flake for Zugvögel Festival infra: one host `pretix-server-01`, declarative services under `zugvoegel.services.*`, secrets via sops-nix, public HTTPS via nginx.

## Context and scope

- **In scope:** NixOS modules, host config, backup, monitoring, Docker app stacks (Pretix, Schwarmplaner, 99trees, Wedding catcher), CI deploy wiring.
- **Out of scope:** Application source — services run from external Docker images and separate repos.
- **External:** S3-compatible backup storage, Let's Encrypt, GitHub Actions SSH deploy.

## Building blocks

| Module | Role |
|--------|------|
| pretix | Ticketing stack: Docker + Postgres + Redis + nginx |
| schwarmplaner | Multi-instance volunteer planning; CI via `deploy` user |
| 99trees | Multi-instance field game; CI via shared `deploy` user |
| backup | Per-service restic jobs + `backup-restore` helper |
| monitoring | Grafana / Loki / Prometheus / Alloy (+ dashboards) |
| bank-automation | Scheduled Pretix bank reconciliation (optional) |
| wedding-catcher | Optional single-container app |

Host wiring in `configuration.nix`; modules auto-exported from `flake.nix`.

## Runtime view

Internet → nginx (ACME) → Docker services on localhost ports. Restic timers push encrypted backups to S3. Monitoring collects metrics/logs; public access via nginx when hosts configured.

## Crosscutting

- Service namespace: `config.zugvoegel.services.<name>`.
- Secrets: sops-nix env files per service/instance; prefer password files over inline store values.
- CI deploy: unprivileged `deploy` user (Schwarmplaner, 99trees) — not root SSH.
- Public nginx vhosts: TLS via ACME plus security headers on proxy locations.
- Backup URL pattern: `${s3BaseUrl}/${bucketPrefix}-${serviceName}`.

## Key decisions

- Per-module detail in `modules/<name>/README.md`; CI apps use scoped `*-deploy-backup` helpers on PATH.