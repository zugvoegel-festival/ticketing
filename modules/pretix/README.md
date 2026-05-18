# Pretix

**Purpose:** NixOS module for Pretix ticketing in Docker with Postgres, Redis, nginx, and ACME.

- `default.nix` — options under `zugvoegel.services.pretix`, Docker containers, nginx vhost, sops secret `pretix-envfile`
- `pretix-cfg.nix` — Pretix settings fragment imported by the container config

**Depends on:** sops-nix, nginx, Docker OCI backend.
