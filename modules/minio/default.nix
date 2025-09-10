{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.zugvoegel.services.minio;
in
{
  options.zugvoegel.services.minio = {
    enable = mkEnableOption "MinIO object storage service";

    host = mkOption {
      type = types.str;
      default = "minio.zugvoegelfestival.org";
      example = "s3.example.com";
      description = "Hostname for the MinIO service";
    };

    consoleHost = mkOption {
      type = types.str;
      default = "minio-console.zugvoegelfestival.org";
      example = "minio-console.example.com";
      description = "Hostname for the MinIO console";
    };

    acmeMail = mkOption {
      type = types.str;
      default = "webmaster@zugvoegelfestival.org";
      example = "admin@example.com";
      description = "Email for ACME certificate registration";
    };

    dataPath = mkOption {
      type = types.str;
      default = "/var/lib/minio/data";
      description = "Path where MinIO will store data";
    };

    configPath = mkOption {
      type = types.str;
      default = "/var/lib/minio/config";
      description = "Path where MinIO will store configuration";
    };

    port = mkOption {
      type = types.port;
      default = 9000;
      description = "Port for MinIO API server";
    };

    consolePort = mkOption {
      type = types.port;
      default = 9001;
      description = "Port for MinIO console";
    };
  };

  config = mkIf cfg.enable {
    # SOPS secrets for MinIO credentials
    sops.secrets.minio-envfile = {
      owner = "minio";
      group = "minio";
    };

    # MinIO service configuration
    services.minio = {
      enable = true;
      listenAddress = "127.0.0.1:${toString cfg.port}";
      consoleAddress = "127.0.0.1:${toString cfg.consolePort}";
      dataDir = [ cfg.dataPath ];
      configDir = cfg.configPath;
      rootCredentialsFile = config.sops.secrets.minio-envfile.path;
    };

    # Ensure data and config directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0750 minio minio -"
      "d ${cfg.configPath} 0750 minio minio -"
    ];

    security.acme = {
      acceptTerms = true;
      defaults.email = "${cfg.acmeMail}";
    };

    # Nginx reverse proxy for MinIO API

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.consoleHost}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString cfg.consolePort}";
          proxyWebsockets = true;
        };
      };
    };

    services.nginx.virtualHosts."${cfg.host}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}
