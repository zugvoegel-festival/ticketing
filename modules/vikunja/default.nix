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
      environmentFiles = [ config.sops.secrets.vikunja-envfile.path ];
      frontendHostname = cfg.host;
      frontendScheme = "https";
      settings = {
        mailer = {
          enabled = true;
          host = "smtp.ionos.de";
          username = "no-reply@feuersalamander-nippes.de";
          fromemail = "no-reply@feuersalamander-nippes.de";
          port = 587;
          authtype = "plain";

        };
        service = {
          enableregistration = true;
          customlogourl = "http://feuersalamander-nippes.de/wp-content/themes/vito13-child-of-twentythirteen/img/site-logos/feuersalamander-logoicon.png";
        };
        log.mail = "on";
        defaulsettings = {
          discoverable_by_name = true;
          week_start = 1;


        };
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
