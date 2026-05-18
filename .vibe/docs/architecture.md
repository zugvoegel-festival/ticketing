# Architecture

## Introduction and goals

NixOS flake for Zugvögel Festival infra: one host `pretix-server-01`, declarative services under `zugvoegel.services.*`, secrets via sops-nix, public HTTPS via nginx.

## Context and scope

- **In scope:** NixOS modules, host config, backup, monitoring, Docker app stacks, deploy wiring for CI.
- **Out of scope:** Application source (Pretix, Schwarmplaner, 99trees live in separate repos/images).
- **External:** S3-compatible backup storage (e.g. B2), Let's Encrypt, GitHub Actions SSH deploy.

## Building blocks

| Layer | Location | Role |
|-------|----------|------|
| Host config | `configuration.nix`, `hardware-configuration.nix` | Enable services, hosts, ports, backup jobs |
| Modules | `modules/*/default.nix` | Reusable NixOS service definitions |
| Flake | `flake.nix` | Exports `nixosConfigurations` + auto-discovered `nixosModules` |
| Secrets | `secrets/secrets.yaml` | Encrypted env files consumed by sops-nix |

## Runtime view

Internet → nginx (80/443, ACME) → Docker services (Pretix, Schwarmplaner, 99trees, …). Restic timers push encrypted backups to S3. Monitoring stack collects metrics/logs locally or via nginx.

## Crosscutting

- All custom services: `config.zugvoegel.services.<name>`.
- CI deploy: unprivileged `deploy` user with scoped sudo (Schwarmplaner, 99trees) — not root SSH keys.
- Backup repo URL: `${s3BaseUrl}/${bucketPrefix}-${serviceName}`.
- Firewall: public 80/443; Docker bridges often `trustedInterfaces`.

## Key decisions

- Flake auto-imports every `modules/<name>/default.nix` via `readDir ./modules`.
- Module READMEs hold per-service detail; this file holds cross-module view only.
