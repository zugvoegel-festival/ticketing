{ config, lib, ... }:
with lib;
let
  cfg = config.zugvoegel.services.vikunja;
in
{
  options.zugvoegel.services.vikunja = {
    enable = mkEnableOption "vikunja service";
    host = mkOption {
      type = types.str;
      default = "brett.feuersalamander-nippes.de";
      example = "todo.url.de";
      description = "Host serving service";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets.vikunja-envfile = { };

    services.vikunja = {
      enable = true;
      environmentFiles = [ sops.secrets.vikunja-envfile.path ];
      frontendHostname = cfg.host;
      frontendScheme = "https";
      settings = {
        mailer.enable = true;
        mailer.host = "smtp.ionos.de";
        mailer.username = "no-reply@feuersalamander-nippes.de";
        mailer.frommail = "no-reply@feuersalamander-nippes.de";
      };
    };

    # nginx reverse proxy
    services.nginx.virtualHosts."${cfg.host}" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:3456";
    };
  };
}
