{ lib, config, ... }:
with lib;
let cfg = config.zugvoegel.services.monitoring.prometheus;
in
{

  options.zugvoegel.services.monitoring.prometheus = {
    enable = mkEnableOption "prometheus node exporter";

    port-exporter = mkOption {
      type = types.int;
      default = 9100;
      example = 3000;
      description = "Port for prometheus exporter";
    };
    host = mkOption {
      type = types.str;
      default = null;
      example = "demo.megaclan3000.de";
      description = "Host serving pretix web service";
    };
  };
  config = mkIf cfg.enable {

    services.prometheus = {
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = cfg.port-exporter;
        };
      };

      scrapeConfigs = [
        {
          job_name = "PrometheusExporter";
          static_configs = [{
            targets = [ "127.0.0.1:${toString cfg.port-exporter}" ];
          }];
        }
      ];
    };
    sops.secrets.metrics-basicAuth = { };

    # nginx reverse proxy
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.host}" = {
        # basicAuthFile = config.sops.secrets.metrics-basicAuth;
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port-exporter}";
      };
    };
  };
}
