# Backup / restore

Restic via `zugvoegel.services.backup` (`modules/backup/default.nix`). Each key under `services.backup.services` becomes a **separate** S3 repository and systemd timer.

## Secrets (once for all jobs)

Edit `secrets/secrets.yaml` with sops:

```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

- **`backup-envfile`** — S3 credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, …)
- **`backup-passwordfile`** — single line: restic repo password (shared across repos here)

On machine: `/run/secrets/backup-envfile`, `/run/secrets/backup-passwordfile`.

## Current jobs (see `configuration.nix`)

Align names with `services.restic.backups.<name>` → units `restic-backups-<name>.service` / `.timer`.

- **pretix-db** — DB type postgresql, dumps via `docker exec` into `dumpPath`, then path backed up.
- **pretix-data** — file backup under configured paths + excludes.
- **schwarmplaner-prod** / **schwarmplaner-test** — file backup of SQLite data dirs (`/var/lib/schwarmplaner-{prod,test}/data`); excludes `*.db-journal`, `*.db-wal`, `*.db-shm` so open DB is not copied inconsistently (stop app or accept crash-consistent copy if you override).

Repository: `''${s3BaseUrl}/${bucketPrefix}-${serviceName}''` e.g. `s3:https://s3.us-west-004.backblazeb2.com/zv-backups-pretix-db` when `bucketPrefix = "zv-backups"`.

## CLI

`backup-restore` is installed on the server (generated from `scripts/backup-restore.sh` with service list from Nix).

```bash
backup-restore list-services
backup-restore status
backup-restore backup pretix-db
backup-restore list-snapshots pretix-data
backup-restore restore pretix-data latest /tmp/out
```

Direct systemd:

```bash
systemctl start restic-backups-pretix-db.service
journalctl -u restic-backups-pretix-db.service -e
systemctl list-timers 'restic-backups-*'
```

## Restore (sketch)

1. `backup-restore list-snapshots <service>` then `restore <service> <id> /tmp/r`.
2. **DB**: import SQL from restored tree into the running DB container (paths under restore mirror dump layout).
3. **Files**: stop service, copy restored files into live data dir, fix ownership, start service.

## Add a job

1. Add attr under `zugvoegel.services.backup.services` in `configuration.nix` (`type` `database` | `files`, schedule, paths/container fields).
2. Deploy (`./deploy.sh`).
3. `backup-restore init <newname>` if repo not yet created (`restic-init-repositories` also runs early after boot).

## Troubleshooting

- Failed unit: `systemctl status restic-backups-<name>.service` + journal.
- S3: verify env file and bucket name `${bucketPrefix}-${name}`.
