{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.schwarmplaner;

  # Wrapper script for pre-deploy / pre-rollback SQLite backups. Allows the
  # `deploy` user to take a consistent snapshot of an instance's data dir
  # without granting broad sudo (only this script + a couple of explicit
  # systemctl/docker commands are sudo-able).
  #
  # Usage: schwarmplaner-deploy-backup <test|prod> [label]
  # Filename: schwarmplaner-<env>-<label>-<timestamp>.tar.gz
  deployBackupScript = pkgs.writeShellScriptBin "schwarmplaner-deploy-backup" ''
    set -euo pipefail

    # Created files must be root-only (0600) so the deploy user can trigger
    # backups but never read tarballs (which contain bcrypt hashes + active
    # invite tokens). The directory itself is enforced 0700 via tmpfiles.
    umask 077

    ENV="''${1:-}"
    LABEL="''${2:-backup}"

    case "$ENV" in
      test|prod) ;;
      *)
        echo "usage: schwarmplaner-deploy-backup <test|prod> [label]" >&2
        exit 1
        ;;
    esac

    DATA_DIR="/var/lib/schwarmplaner-$ENV"
    BACKUP_DIR="/var/backups/schwarmplaner-$ENV"
    SERVICE="docker-schwarmplaner-$ENV.service"
    TS=$(date +%Y-%m-%d-%H%M%S)
    NAME="schwarmplaner-$ENV-$LABEL-$TS.tar.gz"

    # tmpfiles owns the directory (declared in the module). Re-assert mode in
    # case it got loosened by something out-of-band.
    ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$BACKUP_DIR"

    # Stop the container for an on-disk-consistent SQLite snapshot. Keep going
    # if the unit doesn't exist yet (first-ever deploy).
    ${pkgs.systemd}/bin/systemctl stop "$SERVICE" || true

    if [ -d "$DATA_DIR/data" ]; then
      ${pkgs.gnutar}/bin/tar -czf "$BACKUP_DIR/$NAME" -C "$DATA_DIR" data
      ${pkgs.coreutils}/bin/chmod 0600 "$BACKUP_DIR/$NAME"
      SIZE=$(${pkgs.coreutils}/bin/du -h "$BACKUP_DIR/$NAME" | ${pkgs.coreutils}/bin/cut -f1)
      echo "Backup: $BACKUP_DIR/$NAME ($SIZE)"
    else
      echo "(no data directory yet at $DATA_DIR/data — skipping tar)"
    fi

    ${pkgs.systemd}/bin/systemctl start "$SERVICE" || true

    # Keep the 10 most-recent backups for this env.
    cd "$BACKUP_DIR"
    ls -t schwarmplaner-"$ENV"-*.tar.gz 2>/dev/null \
      | tail -n +11 \
      | xargs -r rm -f || true
  '';

  # Container for a single schwarmplaner instance. Each instance gets its
  # own data volume (SQLite file lives inside) and SOPS env-file with
  # NUXT_SESSION_PASSWORD + SCHWARM_JWT_SECRET_KEY.
  createContainer =
    instanceName: instanceConfig: secretPath:
    {
      name = "schwarmplaner-${instanceName}";
      value = {
        image = instanceConfig.app-image;
        ports = [ "${toString instanceConfig.port}:3000" ];
        volumes = [
          "/var/lib/schwarmplaner-${instanceName}/data:/app/data"
        ];
        environmentFiles = [ secretPath ];
        extraOptions = [
          "--pull=always"
          "--network=schwarmplaner-net"
        ];
      };
    };

  # Ensures the per-instance data directory exists with locked-down perms so
  # the unprivileged `deploy` user (used by GitHub Actions) cannot read the
  # live SQLite file (which holds bcrypt hashes + active invite tokens). The
  # container itself runs as root and gets bypass access regardless of mode.
  createDataDirService =
    instanceName: _instanceConfig:
    {
      name = "init-schwarmplaner-${instanceName}-data-dir";
      value = {
        description = "Create schwarmplaner ${instanceName} data directory";
        wantedBy = [ "multi-user.target" ];
        before = [ "docker-schwarmplaner-${instanceName}.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /var/lib/schwarmplaner-${instanceName}/data
          chown -R root:root /var/lib/schwarmplaner-${instanceName}/data
          chmod 700 /var/lib/schwarmplaner-${instanceName}
          chmod 700 /var/lib/schwarmplaner-${instanceName}/data
        '';
      };
    };

  # nginx vhost terminates TLS and forwards to the container's host port.
  # Optional `serverAliases` get covered by an explicit ACME cert below.
  createNginxVirtualHost =
    instanceName: instanceConfig:
    if instanceConfig.host != null then
      let
        aliases = instanceConfig.serverAliases or [ ];
        useExtraDomains = aliases != [ ];
      in
      {
        "${instanceConfig.host}" = {
          serverAliases = aliases;
          enableACME = !useExtraDomains;
          useACMEHost = if useExtraDomains then instanceConfig.host else null;
          forceSSL = true;
          locations."/".proxyPass = "http://localhost:${toString instanceConfig.port}";
          locations."/".extraConfig = ''
            client_max_body_size 64M;
            proxy_read_timeout 120s;
            proxy_connect_timeout 60s;
            proxy_send_timeout 120s;
            add_header X-Content-Type-Options "nosniff" always;
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header Referrer-Policy "strict-origin-when-cross-origin" always;
          '';
        };
      }
    else
      { };
in
{
  options.zugvoegel.services.schwarmplaner = {
    enable = mkEnableOption "schwarmplaner service";

    deployAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA... github-actions-schwarmplaner" ];
      description = ''
        SSH public keys for the unprivileged `deploy` user used by the
        schwarmplaner GitHub Actions workflows (deploy.yml + rollback.yml).
        The user is created only when this list is non-empty and gets a
        narrow sudoers rule covering exactly these commands:
          - docker pull manulinger/schwarmplaner *
          - systemctl restart docker-schwarmplaner-{test,prod}.service
          - schwarmplaner-deploy-backup <env> [label]
      '';
    };

    instances = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            host = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "schwarmplaner.zugvoegelfestival.org";
              description = "Public hostname serving this instance.";
            };

            app-image = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "manulinger/schwarmplaner:prod-latest";
              description = "Docker image (with tag) to run for this instance.";
            };

            acmeMail = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "webmaster@zugvoegelfestival.org";
              description = "Email address used for ACME / Let's Encrypt cert renewal.";
            };

            port = mkOption {
              type = types.port;
              default = 3303;
              description = "Host port that maps to the container's internal port 3000.";
            };

            serverAliases = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "www.schwarmplaner.zugvoegelfestival.org" ];
              description = "Additional hostnames covered by this instance's TLS certificate.";
            };
          };
        }
      );
      default = { };
      description = "Per-environment schwarmplaner instances (e.g. test, prod).";
    };
  };

  config = mkIf cfg.enable {
    security.acme = mkIf (builtins.length (builtins.attrNames cfg.instances) > 0) {
      acceptTerms = true;
      defaults.email =
        let
          mails = lib.filter (x: x != null) (
            map (n: (builtins.getAttr n cfg.instances).acmeMail) (builtins.attrNames cfg.instances)
          );
        in
        if mails != [ ] then builtins.head mails else "webmaster@zugvoegelfestival.org";

      certs = lib.mkMerge (
        map
          (instanceName:
            let
              instanceConfig = builtins.getAttr instanceName cfg.instances;
              aliases = instanceConfig.serverAliases or [ ];
            in
            if instanceConfig.host != null && aliases != [ ] then
              {
                "${instanceConfig.host}" = {
                  extraDomainNames = aliases;
                  group = "nginx";
                  webroot = "/var/lib/acme/acme-challenge";
                };
              }
            else
              { }
          )
          (builtins.attrNames cfg.instances)
      );
    };

    # SOPS secret per instance. Provision in secrets.yaml as
    # `schwarmplaner-<name>-envfile` (NUXT_SESSION_PASSWORD, SCHWARM_JWT_SECRET_KEY, …).
    sops.secrets = builtins.listToAttrs (
      map
        (instanceName: {
          name = "schwarmplaner-${instanceName}-envfile";
          value = { };
        })
        (builtins.attrNames cfg.instances)
    );

    # Pre-create per-instance backup dirs as root-only (0700). The wrapper
    # script writes tarballs with umask 077, so the deploy user can trigger
    # backups but never read the resulting files.
    systemd.tmpfiles.rules =
      map
        (instanceName: "d /var/backups/schwarmplaner-${instanceName} 0700 root root -")
        (builtins.attrNames cfg.instances);

    systemd.services = lib.mkMerge [
      (builtins.listToAttrs (
        map
          (instanceName:
            createDataDirService instanceName (builtins.getAttr instanceName cfg.instances)
          )
          (builtins.attrNames cfg.instances)
      ))
      {
        init-schwarmplaner-net = {
          description = "Create the docker network bridge schwarmplaner-net";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script =
            let
              dockercli = "${config.virtualisation.docker.package}/bin/docker";
            in
            ''
              check=$(${dockercli} network ls | grep "schwarmplaner-net" || true)
              if [ -z "$check" ]; then
                ${dockercli} network create schwarmplaner-net
              else
                echo "schwarmplaner-net already exists in docker"
              fi
            '';
        };
      }
    ];

    virtualisation.oci-containers = {
      backend = "docker";
      containers = builtins.listToAttrs (
        map
          (instanceName:
            let
              instanceConfig = builtins.getAttr instanceName cfg.instances;
              secretName = "schwarmplaner-${instanceName}-envfile";
              secretPath = builtins.getAttr secretName config.sops.secrets;
            in
            createContainer instanceName instanceConfig secretPath.path
          )
          (builtins.attrNames cfg.instances)
      );
    };

    services.nginx = mkIf (builtins.length (builtins.attrNames cfg.instances) > 0) {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = lib.mkMerge (
        map
          (instanceName:
            createNginxVirtualHost instanceName (builtins.getAttr instanceName cfg.instances)
          )
          (builtins.attrNames cfg.instances)
      );
    };

    # ---------------------------------------------------------------------
    # Deploy user (used by GitHub Actions schwarmplaner workflows)
    # ---------------------------------------------------------------------
    # Created only when at least one pubkey is configured. Has NO docker
    # group membership (which would be equivalent to root via container
    # escapes); instead it goes through a narrow sudoers allow-list below.

    environment.systemPackages = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      deployBackupScript
    ];

    # Sudoers gotchas observed on NixOS 25.11 / sudo 1.9.17:
    #   1. `:` and `=` inside command args MUST be backslash-escaped (sudoers
    #      treats them as tag/option separators). NixOS does not auto-escape
    #      `security.sudo.extraRules.commands.command`, so we do it here.
    #   2. sudo on NixOS does NOT canonicalize symlinks when matching commands
    #      against sudoers rules. So if we used `${pkgs.foo}/bin/foo` (a Nix
    #      store path), a user invoking `sudo foo` (resolved via secure_path
    #      to `/run/current-system/sw/bin/foo`, which is a SYMLINK to the Nix
    #      store path) would NOT match — sudo prompts for a password.
    #      Workaround: use the stable wrapper paths under
    #      `/run/current-system/sw/bin/…`, which are exactly the paths sudo
    #      sees post-secure_path-lookup.
    security.sudo.extraRules = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = ''/run/current-system/sw/bin/docker pull manulinger/schwarmplaner\:*'';
            options = [ "NOPASSWD" ];
          }
          {
            # The schwarmplaner GitHub Actions workflows pass the fully
            # qualified image (`docker.io/manulinger/schwarmplaner:<tag>`),
            # so allow that variant too. Keeping both rules explicit instead
            # of using a leading `*` wildcard avoids accidentally permitting
            # `docker pull <attacker>/manulinger/schwarmplaner:foo`.
            command = ''/run/current-system/sw/bin/docker pull docker.io/manulinger/schwarmplaner\:*'';
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart docker-schwarmplaner-test.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart docker-schwarmplaner-prod.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/schwarmplaner-deploy-backup";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/schwarmplaner-deploy-backup *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
