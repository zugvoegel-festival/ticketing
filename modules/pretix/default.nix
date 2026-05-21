{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.zugvoegel.services.pretix;

  runtimeContainer = import ../../lib/runtime-container.nix { inherit lib pkgs; };

  pretixConfig = import ./pretix-cfg.nix { inherit pkgs cfg; };

  pretixDeployDir = "/var/lib/pretix/deploy";

  pretixRestartScript = runtimeContainer.mkRestartContainerScript {
    scriptName = "pretix-restart-container";
    deployDir = pretixDeployDir;
    imageRepo = "manulinger/zv-ticketing";
    instances = [
      {
        env = "prod";
        containerName = "pretix";
        hostPort = cfg.port;
        containerPort = 80;
        dataVolume = "${cfg.pretixDataPath}:/data";
        envFile = config.sops.secrets.pretix-envfile.path;
        network = "pretix-net";
        extraRunArgs = "-v ${pretixDeployDir}/pretix.cfg:/etc/pretix/pretix.cfg:ro";
      }
    ];
  };

  deployBackupScript = pkgs.writeShellScriptBin "pretix-deploy-backup" ''
    set -euo pipefail
    umask 077

    LABEL="''${1:-predeploy}"
    BACKUP_DIR="/var/backups/pretix-deploy"
    TS=$(date +%Y-%m-%d-%H%M%S)
    NAME="pretix-$LABEL-$TS.tar.gz"
    DOCKER="${pkgs.docker}/bin/docker"

    ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$BACKUP_DIR"

    "$DOCKER" stop pretix 2>/dev/null || true

    if [ -d /var/lib/pretix-data/data ]; then
      ${pkgs.gnutar}/bin/tar -czf "$BACKUP_DIR/$NAME" -C /var/lib/pretix-data data
      ${pkgs.coreutils}/bin/chmod 0600 "$BACKUP_DIR/$NAME"
      SIZE=$(${pkgs.coreutils}/bin/du -h "$BACKUP_DIR/$NAME" | ${pkgs.coreutils}/bin/cut -f1)
      echo "Backup: $BACKUP_DIR/$NAME ($SIZE)"
    else
      echo "(no pretix data directory yet — skipping tar)"
    fi

    ${pretixRestartScript}/bin/pretix-restart-container prod || true

    cd "$BACKUP_DIR"
    ls -t pretix-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f || true
  '';
in
{
  options.zugvoegel.services.pretix = {
    enable = mkEnableOption "Pretix ticketing service";

    host = mkOption {
      type = types.str;
      example = "demo.megaclan3000.de";
      description = "Host serving pretix web service";
    };

    pretixImage = mkOption {
      type = types.str;
      default = "manulinger/zv-ticketing:pretix-cliques";
      example = "manulinger/zv-ticketing:pretix-cliques";
      description = ''
        Git SSOT for the Pretix app image (registry/repo:tag). Bumped in
        `environments/pretix.nix`. On nixos-rebuild, the tag is reconciled into
        `/var/lib/pretix/deploy/prod-image`; CI uses `pretix-restart-container`.
      '';
    };

    instanceName = mkOption {
      type = types.str;
      default = "My Pretix Instance";
      example = "Awesome Pretix";
      description = "Name of the Pretix instance";
    };

    acmeMail = mkOption {
      type = types.str;
      example = "admin@pretix.eu";
      description = "Email for SSL Certificate Renewal";
    };

    pretixDataPath = mkOption {
      type = types.str;
      default = "/var/lib/pretix-data/data";
      example = "/var/lib/path-to-pretix-data";
      description = "Path to use for persisten pretix data";
    };

    port = mkOption {
      type = types.port;
      default = 12345;
      description = "Port for Pretix web service";
    };

    enableDangerousMaintenanceTools = mkOption {
      type = types.bool;
      default = false;
      description = ''
        When true, installs destructive helpers (e.g. nuke-docker) on PATH.
        Keep false on production hosts.
      '';
    };

    deployAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA... github-actions-pretix" ];
      description = ''
        SSH public keys merged into the shared `deploy` user for pretix
        GitHub Actions workflows in the ticketing repo. Grants narrow sudo for:
          - pretix-restart-container prod [tag]
          - pretix-deploy-backup [label]
      '';
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages =
      let
        restart-all-pretix =
          pkgs.writeShellScriptBin "restart-all-pretix" # sh
            ''
              systemctl stop docker-postgresql.service docker-redis.service pretix-container.service
              systemctl restart init-pretix-net.service
              systemctl restart init-pretix-data.service
              systemctl start docker-postgresql.service docker-redis.service pretix-container.service
            '';

        nuke-docker =
          pkgs.writeShellScriptBin "nuke-docker" # sh
            ''
              ${pkgs.docker}/bin/docker image prune -a
              ${pkgs.docker}/bin/docker system prune -a
            '';
      in
      [ restart-all-pretix pretixRestartScript ]
      ++ optional cfg.enableDangerousMaintenanceTools nuke-docker
      ++ optional (cfg.deployAuthorizedKeys != [ ]) deployBackupScript;

    systemd.tmpfiles.rules =
      [
        "d ${pretixDeployDir} 0755 root root -"
      ]
      ++ optionals (cfg.deployAuthorizedKeys != [ ]) [
        "d /var/backups/pretix-deploy 0700 root root -"
      ];

    sops.secrets.pretix-envfile = { };

    system.activationScripts = mkMerge [
      (runtimeContainer.mkSyncRuntimeImageActivation {
        name = "pretixRuntimeImages";
        deployDir = pretixDeployDir;
        instances = [
          {
            env = "prod";
            image = cfg.pretixImage;
          }
        ];
      })
      {
        pretixRuntimeConfig = {
          text = ''
            install -d -m 0755 ${pretixDeployDir}
            cp ${pretixConfig} ${pretixDeployDir}/pretix.cfg
          '';
        };
      }
    ];

    systemd.services.init-pretix-net = {
      description = "Create the network bridge pretix-net";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";
      script =
        let
          dockercli = "${config.virtualisation.docker.package}/bin/docker";
        in
        ''
          check=$(${dockercli} network ls | grep "pretix-net" || true)
          if [ -z "$check" ]; then
            ${dockercli} network create pretix-net
          else
            echo "pretix-net already exists in docker"
          fi
        '';
    };

    systemd.services.pretix-container = {
      description = "Pretix app container (runtime image pin)";
      after = [
        "docker.service"
        "init-pretix-net.service"
        "docker-postgresql.service"
        "docker-redis.service"
      ];
      wants = [
        "docker-postgresql.service"
        "docker-redis.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.virtualisation.docker.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p ${cfg.pretixDataPath} && chown -R 15371:15371 ${cfg.pretixDataPath}
        ${pretixRestartScript}/bin/pretix-restart-container prod
      '';
    };

    # Sidecars stay declarative; the app image is runtime-pinned (see pretix-container).
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        redis = {
          image = "redis:7.2.3";
          extraOptions = [ "--network=pretix-net" ];
        };

        postgresql = {
          image = "postgres:16.1";
          extraOptions = [ "--network=pretix-net" ];
          environment = {
            POSTGRES_DB = "pretix";
          };
          environmentFiles = [ config.sops.secrets.pretix-envfile.path ];
          volumes = [ "/var/lib/pretix-postgresql/data:/var/lib/postgresql/data" ];
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "${cfg.acmeMail}";
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.host}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port}";
        locations."/".extraConfig = ''
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        '';
      };
    };

    security.sudo.extraRules = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/pretix-restart-container";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/pretix-restart-container *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/pretix-deploy-backup";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/pretix-deploy-backup *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
