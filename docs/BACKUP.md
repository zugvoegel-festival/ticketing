# Backup and Restore System

This document describes the redesigned backup system for Zugvoegel Festival services, which provides individual backup and restore capabilities for each service.

## Overview

The backup system is now organized around **individual services**, each with its own:
- Dedicated S3 repository (bucket)
- Backup schedule
- Backup type (database dumps or file backups)
- Restore capability

## Backup Services

| Service | Type | Description | Schedule | Repository |
|---------|------|-------------|----------|------------|
| `pretix-db` | Database | PostgreSQL database dump | 02:30 | `zv-backups-pretix-db` |
| `pretix-data` | Files | Pretix application data | 03:00 | `zv-backups-pretix-data` |
| `schwarmplaner-db` | Database | MySQL database dump | 02:45 | `zv-backups-schwarmplaner-db` |

## Benefits of Individual Service Backups

1. **Independent Restores**: Restore only the service you need without affecting others
2. **Separate Schedules**: Different backup frequencies for different services
3. **Service-Specific Configuration**: Tailored backup settings (exclusions, retention, etc.)
4. **Better Organization**: Clear separation of backups by service
5. **Incremental Efficiency**: Restic deduplication works better within service boundaries
6. **Granular Monitoring**: Monitor backup success/failure per service

## Usage Examples

### Using the Management Script

The `scripts/backup-restore.sh` script provides easy management:

```bash
# List all configured services
./scripts/backup-restore.sh list-services

# Check backup status for all services
./scripts/backup-restore.sh status

# Check status for a specific service
./scripts/backup-restore.sh status pretix-db

# Run backup manually for a service
./scripts/backup-restore.sh backup pretix-db

# List available snapshots for a service
./scripts/backup-restore.sh list-snapshots pretix-data

# Restore a specific snapshot
./scripts/backup-restore.sh restore pretix-data latest /tmp/restore-pretix
```

### Direct systemctl Commands

Each service has its own systemd service and timer:

```bash
# Manual backup
systemctl start restic-backups-pretix-db.service

# Check backup status
systemctl status restic-backups-pretix-db.service

# View backup logs
journalctl -u restic-backups-pretix-db.service

# List timers and next runs
systemctl list-timers restic-backups-*.timer
```

### Direct Restic Commands

For advanced operations, you can use restic directly:

```bash
# Set environment
export RESTIC_REPOSITORY="s3:https://s3.us-west-004.backblazeb2.com/zv-backups-pretix-db"
export RESTIC_PASSWORD_FILE="/run/secrets/backup-passwordfile"
source /run/secrets/backup-envfile

# List snapshots with details
restic snapshots --tag pretix-db

# Check repository integrity
restic check

# Get repository statistics
restic stats

# Mount backup for browsing (advanced)
mkdir /tmp/backup-mount
restic mount /tmp/backup-mount
```

## Backup Types

### Database Backups

Database backups create SQL dumps before backing them up to restic:

- **PostgreSQL**: Uses `pg_dumpall` to create complete database dumps
- **MySQL**: Uses `mysqldump` to create database-specific dumps
- **Retention**: Keeps 3 most recent dumps locally, all dumps in restic repository
- **Timestamps**: Dumps include timestamp in filename for easy identification

### File Backups

File backups directly backup directories with intelligent exclusions:

- **Exclusions**: Skip temporary files, caches, logs
- **Incremental**: Only changed files are uploaded (restic deduplication)
- **Preservation**: Full file permissions and metadata preserved

## Restore Procedures

### Database Restore

1. **List available snapshots**:
   ```bash
   ./scripts/backup-restore.sh list-snapshots pretix-db
   ```

2. **Restore to temporary location**:
   ```bash
   ./scripts/backup-restore.sh restore pretix-db <snapshot-id> /tmp/db-restore
   ```

3. **Import the database**:
   ```bash
   # For PostgreSQL
   docker exec -i postgresql psql -U postgres < /tmp/db-restore/var/lib/backups/pretix-db/dump_YYYY-MM-DD_HH-MM-SS.sql
   
   # For MySQL
   docker exec -i schwarmplaner-db mysql -u root -pHurraWirFliegen24 schwarmDatabase < /tmp/db-restore/var/lib/backups/schwarmplaner-db/dump_YYYY-MM-DD_HH-MM-SS.sql
   ```

### File Restore

1. **Stop the service** (to avoid conflicts):
   ```bash
   systemctl stop pretix.service  # or relevant service
   ```

2. **Restore files**:
   ```bash
   ./scripts/backup-restore.sh restore pretix-data <snapshot-id> /tmp/file-restore
   ```

3. **Copy files back** (or replace directory):
   ```bash
   cp -r /tmp/file-restore/var/lib/pretix-data/data/* /var/lib/pretix-data/data/
   chown -R pretix:pretix /var/lib/pretix-data/data/  # Fix permissions
   ```

4. **Restart the service**:
   ```bash
   systemctl start pretix.service
   ```

## Monitoring and Alerts

### Systemd Integration

All backups are systemd services with timers, providing:
- Automatic execution on schedule
- Service status monitoring
- Log integration with journald
- Failed service notifications

### Manual Monitoring

```bash
# Check all backup service statuses
for service in pretix-db pretix-data schwarmplaner-db; do
    echo "=== $service ==="
    systemctl status restic-backups-$service.service --no-pager -l | head -10
done

# Check recent backup activity
journalctl -u "restic-backups-*" --since "24 hours ago" --no-pager
```

## Configuration Changes

The new system is configured in `configuration.nix` under `services.backup.services`. Each service can be individually enabled/disabled and configured.

### Adding a New Service

To add a new service to backup:

1. **Add to configuration.nix**:
   ```nix
   services.backup.services.new-service = {
     enable = true;
     type = "database";  # or "files"
     dbType = "postgresql";  # if type is "database"
     containerName = "new-service-db";
     dbUser = "newuser";
     dumpPath = "/var/lib/backups/new-service-db";
     schedule = "02:15";
   };
   ```

2. **Deploy the configuration**:
   ```bash
   ./deploy.sh
   ```

3. **Initialize the repository**:
   ```bash
   ./scripts/backup-restore.sh init new-service
   ```

## Security Notes

- Backup credentials are managed via sops-nix in `/run/secrets/`
- Each service has its own S3 bucket for isolation
- Database passwords are stored in configuration (consider using sops secrets for sensitive passwords)
- Restic repositories are encrypted with the password file

## Troubleshooting

### Backup Failures

1. **Check service status**: `systemctl status restic-backups-<service>.service`
2. **Check logs**: `journalctl -u restic-backups-<service>.service`
3. **Test manually**: `./scripts/backup-restore.sh backup <service>`

### Repository Issues

1. **Check repository**: `restic check` (with proper environment)
2. **Initialize if needed**: `./scripts/backup-restore.sh init <service>`
3. **Verify credentials**: Check `/run/secrets/backup-envfile` and S3 access

### Common Issues

- **Directory not found**: Ensure backup paths exist and are accessible
- **Docker container not running**: Check that the service containers are running
- **Permission denied**: Ensure backup script has proper permissions
- **S3 access denied**: Verify S3 credentials and bucket permissions