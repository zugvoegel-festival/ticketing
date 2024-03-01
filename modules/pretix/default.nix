{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.pretix;
in
{
  options.zugvoegel.services.pretix = {
    # Define option to enable the pretix config
    enable = mkEnableOption "Pretix ticketing service";

    # Define option to set the host
    host = mkOption {
      type = types.str;
      default = null;
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
    metrics-user = mkOption {
      type = types.str;
      default = "user";
      example = "user";
      description = "user for auth for metrics page";
    };
    metrics-password = mkOption {
      type = types.str;
      default = "password";
      example = "supersecretpassword";
      description = "password for auth for metrics page";
    };

    acmeMail = mkOption {
      type = types.str;
      default = null;
      example = "admin@pretix.eu";
      description = "Email for SSL Certificate Renewal";
    };
    pretixDataPath = mkOption {
      type = types.str;
      default = "/var/lib/pretix-data/data";
      example = "/var/lib/path-to-pretix-data";
      description = "Path to use for persisten pretix data";
    };

  };

  config = mkIf cfg.enable {

    # Some helper scripts to help while debugging
    environment.systemPackages =
      let
        restart-all-pretix = pkgs.writeShellScriptBin "restart-all-pretix" /* sh */
          ''
            systemctl stop docker-postgresql.service docker-pretix.service docker-redis.service
            systemctl restart init-pretix-net.service
            systemctl restart init-pretix-data.service
            systemctl start docker-postgresql.service docker-pretix.service docker-redis.service
          '';

        nuke-docker = pkgs.writeShellScriptBin "nuke-docker" /* sh */
          ''
            ${pkgs.docker}/bin/docker image prune -a
            ${pkgs.docker}/bin/docker system prune -a
          '';
      in
      [ restart-all-pretix nuke-docker ];


    sops.secrets.pretix-envfile = { };
    #    sops.secrets.metrics-user = { };
    #    sops.secrets.metrics-password = { };


    # cfg.metrics-user = config.sops.secrets.metrics-user;
    # cfg.metrics-password = config.sops.secrets.metrics-password;

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
      ''
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
            POSTGRES_HOST_AUTH_METHOD = "trust";
            POSTGRES_DB = "pretix";
          };
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
          ports = [ "12345:80" ];
          extraOptions = [ "--network=pretix-net" ];
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
        locations."/".proxyPass = "http://127.0.0.1:12345";
      };
    };
  };
}
