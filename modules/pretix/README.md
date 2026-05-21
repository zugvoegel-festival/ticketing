# Pretix

**Purpose:** NixOS module for Pretix ticketing in Docker with Postgres, Redis, nginx, and ACME.

- `default.nix` — `zugvoegel.services.pretix` options, Docker stack, nginx vhost with security headers, sops `pretix-envfile`; Postgres auth via env file; `deployAuthorizedKeys` + `pretix-deploy-backup` for ticketing-repo CI; `enableDangerousMaintenanceTools` gates `nuke-docker` on PATH
- `pretix-cfg.nix` — Pretix settings fragment mounted into the pretix container

**Depends on:** sops-nix, nginx, Docker OCI backend.

**Image pin:** `environments/pretix.nix` (`pretixImage`). Host deploy via `./deploy.sh`; image-only releases via Pretix CI in this repo.
