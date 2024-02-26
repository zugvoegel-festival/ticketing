{ lib, config, ... }:
with lib;
let
  cfg = config.zugvoegelfestival.services.monitoring.promtail;
in
{

  options.zugvoegelfestival.services.monitoring.promtail = {
    enable = mkEnableOption "promtail log sender";
  };

  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;
      configuration = {

        server = {
          http_listen_port = 28183;
          grpc_listen_port = 0;
        };

        positions = { filename = "/tmp/positions.yml"; };

        clients = [{
          url = "http://localhost:${toString config.zugvoegelfestival.services.monitoring.loki.port}/loki/api/v1/push";
        }];

        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "${config.networking.hostName}";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
    };
  };
}
