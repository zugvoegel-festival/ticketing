# Backup

**Purpose:** Restic backups per named service with shared S3 credentials and restore helper on PATH.

- `default.nix` — `zugvoegel.services.backup` options, `services.restic.backups` jobs, sops secrets `backup-envfile` / `backup-passwordfile`, `backup-restore` wrapper for `scripts/backup-restore.sh`

**Depends on:** sops-nix, restic, service data paths declared in `configuration.nix`.

**Used by:** All enabled services with backup entries in `configuration.nix`.
