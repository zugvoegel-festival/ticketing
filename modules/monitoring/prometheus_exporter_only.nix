{ lib, config, ... }:
with lib;
let cfg = config.zugvoegelfestival.services.monitoring.prometheus_exporters;
in
{

  options.zugvoegelfestival.services.monitoring.prometheus_exporters = {
    enable = mkEnableOption "prometheus node exporter";
    
    port-exporter = mkOption {
      type = types.Integer;
      default = 3000;
      example = 3000;
      description = "Port for prometheus exporter";
    };
    config = mkIf cfg.enable {

      services.prometheus = {
        exporters = {
          node = {
            enable = cfg.enable;
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

        # nginx reverse proxy
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.host}" = {
        enableACME = true;
        forceSSL = true;
        locations."/exporter".proxyPass = "http://127.0.0.1:${toString cfg.port-exporter}";
      };
    };
    };
  };
}
