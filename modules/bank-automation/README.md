# Bank automation

**Purpose:** Scheduled Pretix bank reconciliation via flake input package and sops env file.

- `default.nix` — `zugvoegel.services.bank-automation` enable option, systemd timer/service, sops secret `bank-envfile`

**Depends on:** `bank-automation` flake input, sops-nix.

**Used by:** `configuration.nix` (currently disabled by default).
