{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.trees99;

  deployBackupScript = pkgs.writeShellScriptBin "99trees-deploy-backup" ''
    set -euo pipefail

    umask 077

    ENV="''${1:-}"
    LABEL="''${2:-backup}"

    case "$ENV" in
      test|prod) ;;
      *)
        echo "usage: 99trees-deploy-backup <test|prod> [label]" >&2
        exit 1
        ;;
    esac

    DATA_DIR="/var/lib/99trees-$ENV"
    BACKUP_DIR="/var/backups/99trees-$ENV"
    SERVICE="docker-99trees-$ENV.service"
    TS=$(date +%Y-%m-%d-%H%M%S)
    NAME="99trees-$ENV-$LABEL-$TS.tar.gz"

    ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$BACKUP_DIR"

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

    cd "$BACKUP_DIR"
    ls -t 99trees-"$ENV"-*.tar.gz 2>/dev/null \
      | tail -n +11 \
      | xargs -r rm -f || true
  '';

  createContainer =
    instanceName: instanceConfig: secretPath:
    {
      name = "99trees-${instanceName}";
      value = {
        image = instanceConfig.app-image;
        ports = [ "${toString instanceConfig.port}:3000" ];
        volumes = [
          "/var/lib/99trees-${instanceName}/data:/data"
        ];
        environmentFiles = [ secretPath ];
        extraOptions = [
          "--pull=always"
          "--network=99trees-net"
        ];
      };
    };

  createDataDirService =
    instanceName: _instanceConfig:
    {
      name = "init-99trees-${instanceName}-data-dir";
      value = {
        description = "Create 99trees ${instanceName} data directory";
        wantedBy = [ "multi-user.target" ];
        before = [ "docker-99trees-${instanceName}.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /var/lib/99trees-${instanceName}/data
          chown -R root:root /var/lib/99trees-${instanceName}/data
          chmod 700 /var/lib/99trees-${instanceName}
          chmod 700 /var/lib/99trees-${instanceName}/data
        '';
      };
    };

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
  options.zugvoegel.services.trees99 = {
    enable = mkEnableOption "99trees (Zugvögel field game) service";

    deployAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA... github-actions-99trees" ];
      description = ''
        SSH public keys merged into the shared `deploy` user for 99trees
        GitHub Actions workflows. Requires the deploy user (e.g. from
        schwarmplaner). Grants narrow sudo for:
          - docker pull manulinger/99trees *
          - systemctl restart docker-99trees-prod.service
          - 99trees-deploy-backup <env> [label]
      '';
    };

    instances = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            host = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "spiel.zugvoegelfestival.org";
              description = "Public hostname serving this instance.";
            };

            app-image = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "manulinger/99trees:prod-latest";
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
              default = 3323;
              description = "Host port that maps to the container's internal port 3000.";
            };

            serverAliases = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional hostnames covered by this instance's TLS certificate.";
            };
          };
        }
      );
      default = { };
      description = "Per-environment 99trees instances (e.g. test, prod).";
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

    sops.secrets = builtins.listToAttrs (
      map
        (instanceName: {
          name = "99trees-${instanceName}-envfile";
          value = { };
        })
        (builtins.attrNames cfg.instances)
    );

    systemd.tmpfiles.rules =
      map
        (instanceName: "d /var/backups/99trees-${instanceName} 0700 root root -")
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
        init-99trees-net = {
          description = "Create the docker network bridge 99trees-net";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script =
            let
              dockercli = "${config.virtualisation.docker.package}/bin/docker";
            in
            ''
              check=$(${dockercli} network ls | grep "99trees-net" || true)
              if [ -z "$check" ]; then
                ${dockercli} network create 99trees-net
              else
                echo "99trees-net already exists in docker"
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
              secretName = "99trees-${instanceName}-envfile";
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

    environment.systemPackages = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      deployBackupScript
    ];

    security.sudo.extraRules = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = ''/run/current-system/sw/bin/docker pull manulinger/99trees\:*'';
            options = [ "NOPASSWD" ];
          }
          {
            command = ''/run/current-system/sw/bin/docker pull docker.io/manulinger/99trees\:*'';
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart docker-99trees-prod.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/99trees-deploy-backup";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/99trees-deploy-backup *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
