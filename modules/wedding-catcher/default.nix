{ config, lib, ... }:
with lib;
let
  cfg = config.zugvoegel.services.wedding-catcher;
in
{
  options.zugvoegel.services.wedding-catcher = {
    enable = mkEnableOption "wedding-catcher service";

    host = mkOption {
      type = types.str;
      example = "catch-a-wedding.loco.vision";
      description = "Host serving the wedding-catcher service";
    };

    image = mkOption {
      type = types.str;
      default = "manulinger/wedding-catcher:latest";
      example = "manulinger/wedding-catcher:latest";
      description = "Docker image with tag for wedding-catcher";
    };

    acmeMail = mkOption {
      type = types.str;
      example = "webmaster@zugvoegelfestival.org";
      description = "Email for SSL certificate renewal";
    };

    port = mkOption {
      type = types.port;
      default = 3305;
      description = "Port for wedding-catcher web service";
    };

    dataPath = mkOption {
      type = types.str;
      default = "/var/lib/wedding-catcher";
      example = "/var/lib/wedding-catcher";
      description = "Base path for persistent data (data/ and screenshots/ created underneath)";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets.wedding-catcher-envfile = { };

    # Ensure data directories exist before container starts
    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath}/data 0755 root root -"
      "d ${cfg.dataPath}/screenshots 0755 root root -"
    ];

    virtualisation.oci-containers = {
      backend = "docker";
      containers.wedding-catcher = {
        image = cfg.image;
        ports = [ "${toString cfg.port}:4000" ];
        environment = {
          CONFIG_PATH = "/app/data/config.yaml";
        };
        environmentFiles = [ config.sops.secrets.wedding-catcher-envfile.path ];
        volumes = [
          "${cfg.dataPath}/data:/app/data"
          "${cfg.dataPath}/screenshots:/app/screenshots"
        ];
        extraOptions = [ "--pull=always" ];
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
      };
    };
  };
}
