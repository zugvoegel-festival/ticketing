{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.schwarmplaner;
in
{
  options.zugvoegel.services.schwarmplaner = {
    enable = mkEnableOption "schwarmplaner service";
    host = mkOption {
      type = types.str;
      default = null;
      example = "demo.megaclan3000.de";
      description = "Host serving service";
    };
    frontend-image = mkOption {
      type = types.str;
      default = null;
      example = "dockeruser/repository-name:tag";
      description = "Docker image with tag";
    };
    api-image = mkOption {
      type = types.str;
      default = null;
      example = "dockeruser/repository-name:tag";
      description = "Docker image with tag";
    };
    acmeMail = mkOption {
      type = types.str;
      default = null;
      example = "admin@pretix.eu";
      description = "Email for SSL Certificate Renewal";
    };
  };

  config = mkIf cfg.enable {

    sops.secrets.schwarm-api-envfile = { };

    systemd.services.init-schwarm-net = {
      description = "Create the network bridge schwarm-net";
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
          check=$(${dockercli} network ls | grep "schwarm-net" || true)
          if [ -z "$check" ]; then
            ${dockercli} network create schwarm-net
          else
            echo "schwarm-net already exists in docker"
          fi
        '';
    };

    # systemd.services.docker-pretix.preStart =
    #   ''
    #     mkdir -p ${cfg.pretixDataPath} && chown -R 15371:15371 ${cfg.pretixDataPath}
    #   '';

    virtualisation.oci-containers = {
      backend = "docker"; # Podman is the default backend.
      containers = {
        schwarmplaner-db = {
          image = "mysql";
          ports = [ "3306:3306" ];
          volumes = [
            "/var/lib/schwarmplaner/mysql/conf.d:/etc/mysql/conf.d"
            "/var/lib/schwarmplaner/mysql/data:/var/lib/mysql"
          ];
          environment = {
            MYSQL_DATABASE = "schwarm";
            MYSQL_ROOT_PASSWORD = "schwarmPassword";
            TZ = "Europe/Berlin";
          };
          extraOptions = [ "--network=schwarm-net" ];
        };
        schwarmplaner-api = {

          image = cfg.api-image;
          dependsOn = [ "schwarmplaner-db" ];
          ports = [ "3000:3000" ];
          environmentFiles = [
            config.sops.secrets.schwarm-api-envfile.path
          ];
          extraOptions = [ "--network=schwarm-net" ];
        };

        schwarmplaner-frontend = {

          image = cfg.frontend-image;
          ports = [ "8080:8080" ];
          dependsOn = [ "schwarmplaner-api" ];
          environment = {
            VUE_APP_API_URL = "http://localhost/api";
          };
          extraOptions = [ "--network=schwarm-net" ];
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
        locations."/".proxyPass = "http://localhost:8080";
      };
    };
  };
}
