{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.zugvoegelfestival.services.monitoring.grafana;
in
{

  # [porree:rebuild] trace: warning: Provisioning Grafana datasources with options has been deprecated.
  # [porree:rebuild] Use `services.grafana.provision.datasources.settings` or
  # [porree:rebuild] `services.grafana.provision.datasources.path` instead.

  options.zugvoegelfestival.services.monitoring.grafana = {
    enable = mkEnableOption "Grafana";

    domain = mkOption {
      type = types.str;
      default = "status.zugvoegelfestival.org";
      example = "grafana.myhost.com";
      description = "Domain for grafana";
    };
    port = mkOption {
      type = types.Integer;
      default = 3000;
      example = 3000;
      description = "Port for grafana";
    };
  };

  config = mkIf cfg.enable {

    # SMTP password file
    lollypops.secrets.files."grafana/smtp-password" = {
      owner = "grafana";
      path = "/var/lib/grafana/smtp-password";
    };

    # Backup Graphana dir, contains stateful config
    zugvoegelfestival.services.restic-client.backup-paths-offsite = [ "/var/lib/grafana" ];

    # Graphana fronend
    services.grafana = {

      enable = true;

      settings = {
        server = {
          domain = cfg.domain;
          http_port = cfg.port;
          http_addr = "127.0.0.1";
        };

        # Mail notifications
        # smtp = {
        #  enabled = false;
        #  host = "smtp.sendgrid.net:587";
        # user = "apikey";
        # passwordFile = "${config.lollypops.secrets.files."grafana/smtp-password".path}";
        # fromAddress = "status@pablo.tools";
        # };
      };

      # nginx reverse proxy
      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        virtualHosts."${config.services.grafana.domain}" = {
          enableACME = true;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port}";
        };
      };
      #
      #      provision.datasources.settings =
      #        {
      #          datasources =
      #            [
      #              {
      #                name = "Prometheus localhost";
      #                url = "http://localhost:9090";
      #                type = "prometheus";
      #                isDefault = true;
      #              }
      #              {
      #                name = "loki";
      #                url = "http://localhost:3100";
      #                type = "loki";
      #              }
      #            ];
      #
      #        };
      #
    };
  };
}
