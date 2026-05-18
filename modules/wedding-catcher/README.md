# Wedding catcher

**Purpose:** Optional single-container Docker app with nginx TLS and persistent data dirs.

- `default.nix` — `zugvoegel.services.wedding-catcher` options, OCI container, nginx vhost, sops secret `wedding-catcher-envfile`

**Depends on:** sops-nix, nginx, Docker.

**Used by:** `configuration.nix` (often disabled).
