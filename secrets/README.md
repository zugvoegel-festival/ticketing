# SOPS secrets

Secrets are stored in [`secrets.yaml`](./secrets.yaml) and decrypted at deploy
time via sops-nix. Encryption recipients are defined in [`../.sops.yaml`](../.sops.yaml).

```bash
# Ensure SOPS_AGE_KEY_FILE is set (e.g. ~/.config/sops/age/keys.txt)
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

## Grafana admin password

Add a **single-line** key `grafana-admin-password` (plain password text, no YAML
multiline block required). It is mounted for Grafana as
`/run/secrets/grafana-admin-password` and referenced via Grafana’s `$__file{…}`
mechanism — it must exist before `nixos-rebuild` when monitoring is enabled.

## Pretix PostgreSQL password

The Pretix and PostgreSQL containers both use [`pretix-envfile`](./secrets.yaml).
Extend that env file (same secret, edit with `sops`) with:

- `POSTGRES_PASSWORD=` — required by the official Postgres image (SCRAM auth).
- `PRETIX_DATABASE_PASSWORD=` — same value; overrides `[database] password` per
  [pretix config / env vars](https://docs.pretix.eu/en/latest/admin/config.html).

**Existing installs** that previously used `trust` for Postgres: after you set a
password, either set the password inside the DB to match (`ALTER USER postgres
WITH PASSWORD '…';`) or plan a one-time volume reset if you cannot log in.

## Schwarmplaner cutover (one-time)

When migrating schwarmplaner from the legacy 4-container MySQL stack to the
new single-container SQLite app, the NixOS module in
[`modules/schwarmplaner/default.nix`](../modules/schwarmplaner/default.nix)
expects one SOPS env-file for production (`schwarmplaner-prod-envfile`).

1. **Add prod env-file**

   ```bash
   nix-shell -p sops --run "sops secrets/secrets.yaml"
   ```

   Add the env vars validated by
   `web/server/plugins/02-env-validation.plugin.ts` in the schwarmplaner repo:

   ```yaml
   schwarmplaner-prod-envfile: |
     NUXT_SESSION_PASSWORD=<long random string, ≥32 chars>
     SCHWARM_JWT_SECRET_KEY=<long random string>
     NUXT_ENVIRONMENT=production
   ```

   Generate strong random values with e.g.
   `openssl rand -base64 48 | tr -d '/=+' | head -c 48`.

2. **Remove the legacy keys** once the new instances are running and the
   MySQL container has been decommissioned (see cutover in
   [`DEPLOYMENT.md`](../../schwarmplaner/DEPLOYMENT.md) in the schwarmplaner repo):

   - `schwarm-db-envfile` (legacy MySQL credentials)
   - `schwarm-api-envfile` (legacy Express API env)

3. **Add the GitHub Actions deploy key** to
   `zugvoegel.services.schwarmplaner.deployAuthorizedKeys` in `configuration.nix`:

   ```bash
   ssh-keygen -t ed25519 -C "github-actions-schwarmplaner" -f /tmp/sp-deploy-key -N ""
   cat /tmp/sp-deploy-key.pub
   ```

   - Public key → paste into `configuration.nix` under `deployAuthorizedKeys`.
   - Private key → `SSH_PRIVATE_KEY` in the schwarmplaner GitHub repo.
   - Wipe the local copy: `shred -u /tmp/sp-deploy-key /tmp/sp-deploy-key.pub`.

4. **Deploy the host** so the new SOPS key lands at
   `/run/secrets/schwarmplaner-prod-envfile` and the new authorized
   key takes effect:

   ```bash
   ./update-and-deploy.sh
   ```

5. **Trigger the first schwarmplaner deploy** from the schwarmplaner repo
   (production release script or `v*.*.*` tag → `deploy.yml`).

   GitHub Actions SSH as `deploy`, run `schwarmplaner-deploy-backup prod`, then
   `schwarmplaner-restart-container prod <tag>` (runtime pin under
   `/var/lib/schwarmplaner/deploy/prod-image`).

## 99trees (Zugvögel field game)

The NixOS module [`modules/99trees/default.nix`](../modules/99trees/default.nix)
(`zugvoegel.services.trees99`) expects one SOPS env-file per configured instance
(e.g. `99trees-prod-envfile` for the prod instance in `configuration.nix`).

1. **Add the prod env-file** (edit with `sops secrets/secrets.yaml`):

   ```yaml
   99trees-prod-envfile: |
     NUXT_SESSION_PASSWORD=<≥32 chars random>
     NUXT_ADMIN_INIT_SECRET=<bootstrap secret>
     NUXT_CREW_SESSION_PASSWORD=<≥32 chars random>
     NUXT_ENVIRONMENT=production
   ```

   Generate values: `openssl rand -base64 48 | tr -d '/=+' | head -c 48`

2. **Deploy SSH key** — add the pubkey to
   `zugvoegel.services.trees99.deployAuthorizedKeys` in `configuration.nix`.
   Private key → `SSH_PRIVATE_KEY` in the 99trees GitHub repo. The shared
   `deploy` user must already exist (from schwarmplaner).

3. **Backblaze B2** — create bucket `zv-backups-trees99-prod` (private, same
   region as other `zv-backups-*` buckets). Restic job: `trees99-prod`.

4. **DNS** (before first deploy):

   - `trees.loco.vision` → server A record

5. **Host activation:**

   ```bash
   ./update-and-deploy.sh
   ```

6. **First prod release** — from the 99trees repo, after GitHub secrets are set:

   ```bash
   bash .cursor/skills/release/scripts/release-prod.sh
   ```

   CI runs `99trees-deploy-backup prod`, then `99trees-restart-container prod <tag>`.
