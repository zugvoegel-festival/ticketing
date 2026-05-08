# SOPS secrets

Secrets are stored in [`secrets.yaml`](./secrets.yaml) and decrypted at deploy
time via sops-nix. Encryption recipients are defined in [`../.sops.yaml`](../.sops.yaml).

```bash
# Ensure SOPS_AGE_KEY_FILE is set (e.g. ~/.config/sops/age/keys.txt)
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

## Schwarmplaner cutover (one-time)

When migrating schwarmplaner from the legacy 4-container MySQL stack to the
new single-container SQLite app, the NixOS module in
[`modules/schwarmplaner/default.nix`](../modules/schwarmplaner/default.nix)
expects one SOPS env-file per instance (`schwarmplaner-prod-envfile`,
`schwarmplaner-test-envfile`).

1. **Add per-instance env-files**

   ```bash
   nix-shell -p sops --run "sops secrets/secrets.yaml"
   ```

   Add two new keys with the env vars validated by
   `web/server/plugins/02-env-validation.plugin.ts` in the schwarmplaner repo:

   ```yaml
   schwarmplaner-prod-envfile: |
     NUXT_SESSION_PASSWORD=<long random string, ≥32 chars>
     SCHWARM_JWT_SECRET_KEY=<long random string>
     NUXT_ENVIRONMENT=production
   schwarmplaner-test-envfile: |
     NUXT_SESSION_PASSWORD=<long random string, ≥32 chars>
     SCHWARM_JWT_SECRET_KEY=<long random string>
     NUXT_ENVIRONMENT=test
   ```

   Generate strong random values with e.g.
   `openssl rand -base64 48 | tr -d '/=+' | head -c 48`.

2. **Remove the legacy keys** once the new instances are running and the
   MySQL container has been decommissioned (see cutover in
   [`DEPLOYMENT.md`](../../schwarmplaner/DEPLOYMENT.md) in the schwarmplaner repo):

   - `schwarm-db-envfile` (legacy MySQL credentials)
   - `schwarm-api-envfile` (legacy Express API env)

3. **Add the GitHub Actions deploy key** to
   `users.users.root.openssh.authorizedKeys.keys` in `configuration.nix`:

   ```bash
   ssh-keygen -t ed25519 -C "github-actions-schwarmplaner" -f /tmp/sp-deploy-key -N ""
   cat /tmp/sp-deploy-key.pub
   ```

   - Public key → paste into `configuration.nix` (the file already has a
     `TODO` placeholder line you can replace).
   - Private key → paste into the `SSH_PRIVATE_KEY` GitHub Actions secret
     in the schwarmplaner repo.
   - Wipe the local copy: `shred -u /tmp/sp-deploy-key /tmp/sp-deploy-key.pub`.

4. **Deploy the host** so the new SOPS keys land at
   `/run/secrets/schwarmplaner-{prod,test}-envfile` and the new authorized
   key takes effect:

   ```bash
   ./update-and-deploy.sh
   ```

5. **Trigger the first schwarmplaner deploy** from the schwarmplaner repo:

   ```bash
   bash .cursor/skills/release/scripts/release-test.sh
   ```

   GitHub Actions will build the image, push it to Docker Hub, SSH in, pull,
   and `systemctl restart docker-schwarmplaner-test.service`.
