{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.zugvoegel.services.pretix;

  deployBackupScript = pkgs.writeShellScriptBin "pretix-deploy-backup" ''
    set -euo pipefail
    umask 077

    LABEL="''${1:-predeploy}"
    BACKUP_DIR="/var/backups/pretix-deploy"
    TS=$(date +%Y-%m-%d-%H%M%S)
    NAME="pretix-$LABEL-$TS.tar.gz"

    ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$BACKUP_DIR"

    ${pkgs.systemd}/bin/systemctl stop docker-pretix.service || true

    if [ -d /var/lib/pretix-data/data ]; then
      ${pkgs.gnutar}/bin/tar -czf "$BACKUP_DIR/$NAME" -C /var/lib/pretix-data data
      ${pkgs.coreutils}/bin/chmod 0600 "$BACKUP_DIR/$NAME"
      SIZE=$(${pkgs.coreutils}/bin/du -h "$BACKUP_DIR/$NAME" | ${pkgs.coreutils}/bin/cut -f1)
      echo "Backup: $BACKUP_DIR/$NAME ($SIZE)"
    else
      echo "(no pretix data directory yet — skipping tar)"
    fi

    ${pkgs.systemd}/bin/systemctl start docker-pretix.service || true

    cd "$BACKUP_DIR"
    ls -t pretix-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f || true
  '';
in
{
  options.zugvoegel.services.pretix = {
    # Define option to enable the pretix config
    enable = mkEnableOption "Pretix ticketing service";

    # Define option to set the host
    host = mkOption {
      type = types.str;
      example = "demo.megaclan3000.de";
      description = "Host serving pretix web service";
    };

    pretixImage = mkOption {
      type = types.str;
      default = "manulinger/zv-ticketing:pretix-cliques";
      example = "manulinger/zv-ticketing:pretix-cliques";
      description = "Docker image with tag to deploy for pretix";
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
          - docker pull manulinger/zv-ticketing *
          - systemctl restart docker-pretix.service
          - pretix-deploy-backup [label]
      '';
    };
  };

  config = mkIf cfg.enable {

    # Some helper scripts to help while debugging
    environment.systemPackages =
      let
        restart-all-pretix =
          pkgs.writeShellScriptBin "restart-all-pretix" # sh
            ''
              systemctl stop docker-postgresql.service docker-pretix.service docker-redis.service
              systemctl restart init-pretix-net.service
              systemctl restart init-pretix-data.service
              systemctl start docker-postgresql.service docker-pretix.service docker-redis.service
            '';

        nuke-docker =
          pkgs.writeShellScriptBin "nuke-docker" # sh
            ''
              ${pkgs.docker}/bin/docker image prune -a
              ${pkgs.docker}/bin/docker system prune -a
            '';
      in
      [ restart-all-pretix ]
      ++ optional cfg.enableDangerousMaintenanceTools nuke-docker
      ++ optional (cfg.deployAuthorizedKeys != [ ]) deployBackupScript;

    systemd.tmpfiles.rules = mkIf (cfg.deployAuthorizedKeys != [ ]) [
      "d /var/backups/pretix-deploy 0700 root root -"
    ];

    sops.secrets.pretix-envfile = { };

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
          # Put a true at the end to prevent getting non-zero return code,
          # which will crash the whole service.
          check=$(${dockercli} network ls | grep "pretix-net" || true)
          if [ -z "$check" ]; then
            ${dockercli} network create pretix-net
          else
            echo "pretix-net already exists in docker"
          fi
        '';
    };

    systemd.services.docker-pretix.preStart =
      let
        dockercli = "${config.virtualisation.docker.package}/bin/docker";
      in
      ''
        # Pull the latest image before starting
        ${dockercli} pull ${cfg.pretixImage} || true
        # Ensure data directory exists with correct permissions
        mkdir -p ${cfg.pretixDataPath} && chown -R 15371:15371 ${cfg.pretixDataPath}
      '';

    virtualisation.oci-containers = {
      backend = "docker"; # Podman is the default backend.
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

        pretix = {
          image = cfg.pretixImage;
          volumes =
            let
              pretix-config = import ./pretix-cfg.nix { inherit pkgs cfg; };
            in
            [
              "${pretix-config}:/etc/pretix/pretix.cfg"
              "${cfg.pretixDataPath}:/data"
            ];
          environmentFiles = [ config.sops.secrets.pretix-envfile.path ];
          ports = [ "${toString cfg.port}:80" ];
          extraOptions = [
            "--network=pretix-net"
            "--pull=always"
          ];
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "${cfg.acmeMail}";
    };

    # nginx reverse proxy
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
            command = ''/run/current-system/sw/bin/docker pull manulinger/zv-ticketing\:*'';
            options = [ "NOPASSWD" ];
          }
          {
            command = ''/run/current-system/sw/bin/docker pull docker.io/manulinger/zv-ticketing\:*'';
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart docker-pretix.service";
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
