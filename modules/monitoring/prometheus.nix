{ lib, pkgs, config, flake-self, ... }:
with lib;
let cfg = config.zugvoegelfestival.services.monitoring.prometheus;
in
{

  options.zugvoegelfestival.services.monitoring.prometheus = {
    enable = mkEnableOption "prometheus";
    port = mkOption {
      type = types.Integer;
      default = 9001;
      example = 9001;
      description = "Port for prometheus";
    };
    port-exporter = mkOption {
      type = types.Integer;
      default = 3000;
      example = 3000;
      description = "Port for prometheus exporter";
    };
    config = mkIf cfg.enable {

      services.prometheus = {
        enable = true;
        port = cfg.port;
        # Disable config checks. They will fail because they run sandboxed and
        # can't access external files, e.g. the secrets stored in /run/keys
        # https://github.com/NixOS/nixpkgs/blob/d89d7af1ba23bd8a5341d00bdd862e8e9a808f56/nixos/modules/services/monitoring/prometheus/default.nix#L1732-L1738
        checkConfig = false;

        exporters = {
          node = {
            enable = true;
            enabledCollectors = [ "systemd" ];
            port = cfg.port-exporter;
          };
        };

        scrapeConfigs = [
          {
            job_name = "Prometheus Exporter";
            static_configs = [{
              targets = [ "127.0.0.1:${toString cfg.port-exporter}" ];
            }];
          }
        ];

      };
    };
  };
}
