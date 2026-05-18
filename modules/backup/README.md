# Backup

**Purpose:** Restic backups per named service with shared S3 credentials and restore helper on PATH.

- `default.nix` — `zugvoegel.services.backup` options, per-service restic timers, sops `backup-envfile` / `backup-passwordfile`; MySQL dumps prefer `dbPasswordFile` over inline `dbPassword`; `backup-restore` wraps `scripts/backup-restore.sh`

**Depends on:** sops-nix, restic, service data paths declared in `configuration.nix`.

**Used by:** All enabled services with backup entries in `configuration.nix`.
