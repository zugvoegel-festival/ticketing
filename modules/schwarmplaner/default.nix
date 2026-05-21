{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.schwarmplaner;

  runtimeContainer = import ../../lib/runtime-container.nix { inherit lib pkgs; };

  schwarmplanerDeployDir = "/var/lib/schwarmplaner/deploy";

  instanceNames = builtins.attrNames cfg.instances;

  runtimeInstances =
    map
      (instanceName:
        let
          instanceConfig = cfg.instances.${instanceName};
          secretPath = config.sops.secrets."schwarmplaner-${instanceName}-envfile".path;
        in
        {
          env = instanceName;
          image = instanceConfig.app-image;
          containerName = "schwarmplaner-${instanceName}";
          hostPort = instanceConfig.port;
          containerPort = 3000;
          dataVolume = "/var/lib/schwarmplaner-${instanceName}/data:/app/data";
          envFile = secretPath;
          network = "schwarmplaner-net";
        }
      )
      instanceNames;

  schwarmplanerRestartScript = runtimeContainer.mkRestartContainerScript {
    scriptName = "schwarmplaner-restart-container";
    deployDir = schwarmplanerDeployDir;
    imageRepo = "manulinger/schwarmplaner";
    instances = runtimeInstances;
  };

  deployBackupScript = pkgs.writeShellScriptBin "schwarmplaner-deploy-backup" ''
    set -euo pipefail
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
    CONTAINER="schwarmplaner-$ENV"
    TS=$(date +%Y-%m-%d-%H%M%S)
    NAME="schwarmplaner-$ENV-$LABEL-$TS.tar.gz"
    DOCKER="${pkgs.docker}/bin/docker"

    ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$BACKUP_DIR"

    "$DOCKER" stop "$CONTAINER" 2>/dev/null || true

    if [ -d "$DATA_DIR/data" ]; then
      ${pkgs.gnutar}/bin/tar -czf "$BACKUP_DIR/$NAME" -C "$DATA_DIR" data
      ${pkgs.coreutils}/bin/chmod 0600 "$BACKUP_DIR/$NAME"
      SIZE=$(${pkgs.coreutils}/bin/du -h "$BACKUP_DIR/$NAME" | ${pkgs.coreutils}/bin/cut -f1)
      echo "Backup: $BACKUP_DIR/$NAME ($SIZE)"
    else
      echo "(no data directory yet at $DATA_DIR/data — skipping tar)"
    fi

    ${schwarmplanerRestartScript}/bin/schwarmplaner-restart-container "$ENV" || true

    cd "$BACKUP_DIR"
    ls -t schwarmplaner-"$ENV"-*.tar.gz 2>/dev/null \
      | tail -n +11 \
      | xargs -r rm -f || true
  '';

  createDataDirService =
    instanceName: _instanceConfig:
    {
      name = "init-schwarmplaner-${instanceName}-data-dir";
      value = {
        description = "Create schwarmplaner ${instanceName} data directory";
        wantedBy = [ "multi-user.target" ];
        before = [ "schwarmplaner-${instanceName}-container.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /var/lib/schwarmplaner-${instanceName}/data
          chown -R root:root /var/lib/schwarmplaner-${instanceName}/data
          chmod 700 /var/lib/schwarmplaner-${instanceName}
          chmod 700 /var/lib/schwarmplaner-${instanceName}/data
        '';
      };
    };

  createRuntimeContainerService =
    instanceName:
    {
      name = "schwarmplaner-${instanceName}-container";
      value = {
        description = "Schwarmplaner ${instanceName} app container (runtime image pin)";
        after = [
          "docker.service"
          "init-schwarmplaner-net.service"
          "init-schwarmplaner-${instanceName}-data-dir.service"
        ];
        wantedBy = [ "multi-user.target" ];
        path = [ config.virtualisation.docker.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "${schwarmplanerRestartScript}/bin/schwarmplaner-restart-container ${instanceName}";
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
  options.zugvoegel.services.schwarmplaner = {
    enable = mkEnableOption "schwarmplaner service";

    deployAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA... github-actions-schwarmplaner" ];
      description = ''
        SSH public keys for the unprivileged `deploy` user used by the
        schwarmplaner GitHub Actions workflows (deploy.yml + rollback.yml).
        Narrow sudo:
          - schwarmplaner-restart-container <test|prod> [tag]
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
              description = ''
                Git SSOT (registry/repo:tag). Reconciled to
                `/var/lib/schwarmplaner/deploy/<env>-image` on nixos-rebuild.
              '';
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
    security.acme = mkIf (instanceNames != [ ]) {
      acceptTerms = true;
      defaults.email =
        let
          mails = lib.filter (x: x != null) (
            map (n: cfg.instances.${n}.acmeMail) instanceNames
          );
        in
        if mails != [ ] then builtins.head mails else "webmaster@zugvoegelfestival.org";

      certs = lib.mkMerge (
        map
          (instanceName:
            let
              instanceConfig = cfg.instances.${instanceName};
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
          instanceNames
      );
    };

    sops.secrets = builtins.listToAttrs (
      map
        (instanceName: {
          name = "schwarmplaner-${instanceName}-envfile";
          value = { };
        })
        instanceNames
    );

    systemd.tmpfiles.rules =
      [ "d ${schwarmplanerDeployDir} 0755 root root -" ]
      ++ map
        (instanceName: "d /var/backups/schwarmplaner-${instanceName} 0700 root root -")
        instanceNames;

    system.activationScripts = runtimeContainer.mkSyncRuntimeImageActivation {
      name = "schwarmplanerRuntimeImages";
      deployDir = schwarmplanerDeployDir;
      instances = map (i: { env = i.env; image = i.image; }) runtimeInstances;
    };

    systemd.services = lib.mkMerge [
      (builtins.listToAttrs (
        map
          (instanceName: createDataDirService instanceName cfg.instances.${instanceName})
          instanceNames
      ))
      (builtins.listToAttrs (map (n: createRuntimeContainerService n) instanceNames))
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

    services.nginx = mkIf (instanceNames != [ ]) {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = lib.mkMerge (
        map
          (instanceName: createNginxVirtualHost instanceName cfg.instances.${instanceName})
          instanceNames
      );
    };

    environment.systemPackages =
      [ schwarmplanerRestartScript ]
      ++ optional (cfg.deployAuthorizedKeys != [ ]) deployBackupScript;

    security.sudo.extraRules = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/schwarmplaner-restart-container";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/schwarmplaner-restart-container *";
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
