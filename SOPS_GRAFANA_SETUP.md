# SOPS Integration for Grafana Secrets

The observability module now uses SOPS (Secrets OPerationS) to securely manage Grafana secrets instead of storing them in plain text in the configuration.

## 🔐 How it Works

The Grafana secrets are now:
1. **Stored encrypted** in `secrets/secrets.yaml` using SOPS
2. **Automatically decrypted** at runtime by the SOPS-NixOS integration
3. **Securely provided** to Grafana via file-based configuration

## 📋 Setup Instructions

### 1. First-time Setup (if sops is not installed)

If you need to install sops, you can do it via Nix:
```bash
# Install sops temporarily
nix-shell -p sops
```

Or install it permanently:
```bash
# Add to your system packages
nix-env -iA nixpkgs.sops
```

### 2. Set Your Grafana Secrets

Edit the secrets file to set your secure credentials:
```bash
# Edit the encrypted secrets file
sops secrets/secrets.yaml
```

Add both secrets with secure values:
```yaml
grafana-admin-password: "your-very-secure-password-here"
grafana-secret-key: "your-secure-secret-key-here"
```

**Important**: The secret key should be a random string used for signing cookies and encryption. You can generate one with:
```bash
# Generate a secure random secret key
openssl rand -hex 32
```

### 3. Verify the Secrets are Properly Configured

Check that the secrets are encrypted:
```bash
# View the encrypted file (should show encrypted content)
cat secrets/secrets.yaml | grep -E "(grafana-admin-password|grafana-secret-key)"
```

## 🔧 Current Configuration

The observability module now includes:

```nix
# SOPS secrets configuration
sops.secrets.grafana-admin-password = {
  sopsFile = ../../secrets/secrets.yaml;
  owner = "grafana";
  group = "grafana";
  mode = "0400";
};

sops.secrets.grafana-secret-key = {
  sopsFile = ../../secrets/secrets.yaml;
  owner = "grafana";
  group = "grafana";
  mode = "0400";
};

# Grafana uses the secrets via file references
security = {
  admin_password = config.sops.secrets.grafana-admin-password.path;
  secret_key = config.sops.secrets.grafana-secret-key.path;
};
```

## 🚀 Deployment

After setting up the password in SOPS:

```bash
# Deploy the configuration
sudo nixos-rebuild switch

# Or use your deployment script
./update-and-deploy.sh
```

## 🔍 Verification

1. **Check that the secret files exist:**
   ```bash
   sudo ls -la /run/secrets/grafana-admin-password
   sudo ls -la /run/secrets/grafana-secret-key
   ```

2. **Verify Grafana service is running:**
   ```bash
   sudo systemctl status grafana
   ```

3. **Test login:**
   - Visit https://grafana.zugvoegelfestival.org
   - Username: `admin`
   - Password: `your-very-secure-password-here`

## 🛡️ Security Benefits

Using SOPS provides several security advantages:

- **Encryption at Rest**: Secrets are encrypted in git repository
- **Access Control**: Only authorized users can decrypt secrets
- **Audit Trail**: Changes to secrets are tracked in git
- **Secure Distribution**: Secrets are decrypted only on target machines
- **Runtime Security**: Secret files have restricted permissions (0400)
- **Key Separation**: Admin password and secret key are managed separately

## 🔧 Troubleshooting

### Grafana Won't Start
```bash
# Check if secret file exists and has correct permissions
sudo ls -la /run/secrets/grafana-admin-password

# Check Grafana logs
sudo journalctl -u grafana -f
```

### Can't Decrypt Secrets
```bash
# Verify your key is properly configured
sops -d secrets/secrets.yaml | grep grafana-admin-password
```

### Wrong Permissions on Secret File
The secret file should be owned by `grafana:grafana` with mode `0400`. If not:
```bash
# Restart the sops service
sudo systemctl restart sops-secrets
```

## 🔄 Updating the Password

To change the Grafana admin password:

1. **Edit the encrypted secrets:**
   ```bash
   sops secrets/secrets.yaml
   ```

2. **Update the password value:**
   ```yaml
   grafana-admin-password: "new-secure-password"
   ```

3. **Deploy the change:**
   ```bash
   sudo nixos-rebuild switch
   ```

4. **Restart Grafana (if needed):**
   ```bash
   sudo systemctl restart grafana
   ```

## 📝 Notes

- The secrets are read from files on Grafana startup
- Changes to secrets require Grafana restart
- Keep your SOPS keys secure and backed up
- The secret files are automatically created at:
  - `/run/secrets/grafana-admin-password`
  - `/run/secrets/grafana-secret-key`
- The secret key is used for signing cookies and should be unique per installation

This setup ensures your Grafana secrets are never stored in plain text while maintaining ease of deployment and management.
