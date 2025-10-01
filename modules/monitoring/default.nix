{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.zugvoegel.services.monitoring;
in
{
  options.zugvoegel.services.monitoring = {
    enable = mkEnableOption "monitoring stack (Loki, Grafana, Prometheus, Promtail)";

    grafanaHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "grafana.example.com";
      description = "Host serving Grafana dashboard service";
    };

    prometheusHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "prometheus.example.com";
      description = "Host serving Prometheus metrics service";
    };

    lokiHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "loki.example.com";
      description = "Host serving Loki logs service";
    };

    acmeMail = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@example.com";
      description = "Email for SSL Certificate Renewal";
    };

    grafanaPort = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for Grafana dashboard service";
    };

    lokiPort = mkOption {
      type = types.port;
      default = 3100;
      description = "Port for Loki logs service";
    };

    prometheusPort = mkOption {
      type = types.port;
      default = 9090;
      description = "Port for Prometheus metrics service";
    };

    promtailPort = mkOption {
      type = types.port;
      default = 9080;
      description = "Port for Promtail log collection service";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for monitoring services";
    };
  };

  config = mkIf cfg.enable {
    # Loki - Log aggregation
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server.http_listen_port = cfg.lokiPort;
        common = {
          path_prefix = "/var/lib/loki";
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
          replication_factor = 1;
        };
        schema_config.configs = [
          {
            from = "2020-10-24";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        analytics.reporting_enabled = false;
      };
    };

    # Grafana - Dashboards and visualization
    services.grafana = {
      enable = true;
      settings = {
        server.http_port = cfg.grafanaPort;
        security = {
          admin_user = "admin";
          admin_password = "admin";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:${toString cfg.lokiPort}";
              isDefault = true;
            }
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString cfg.prometheusPort}";
            }
          ];
        };
      };
    };

    # Prometheus - Metrics collection
    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.prometheusPort}" ]; } ];
        }
        {
          job_name = "grafana";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.grafanaPort}" ]; } ];
        }
        {
          job_name = "loki";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.lokiPort}" ]; } ];
        }
      ];
    };

    # Promtail - Log collection
    services.promtail = {
      enable = true;
      configuration = {
        server.http_listen_port = cfg.promtailPort;
        positions.filename = "/tmp/positions.yaml";
        clients = [ { url = "http://127.0.0.1:${toString cfg.lokiPort}/loki/api/v1/push"; } ];
        scrape_configs = [
          # System logs
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels.job = "systemd-journal";
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };

    # Nginx virtual hosts for monitoring services
    services.nginx =
      mkIf (cfg.grafanaHost != null || cfg.prometheusHost != null || cfg.lokiHost != null)
        {
          enable = true;
          virtualHosts =
            (mkIf (cfg.grafanaHost != null) {
              "${cfg.grafanaHost}" = {
                forceSSL = true;
                enableACME = true;
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString cfg.grafanaPort}";
                  proxyWebsockets = true;
                  extraConfig = ''
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  '';
                };
              };
            })
            // (mkIf (cfg.prometheusHost != null) {
              "${cfg.prometheusHost}" = {
                forceSSL = true;
                enableACME = true;
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString cfg.prometheusPort}";
                  extraConfig = ''
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  '';
                };
              };
            })
            // (mkIf (cfg.lokiHost != null) {
              "${cfg.lokiHost}" = {
                forceSSL = true;
                enableACME = true;
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString cfg.lokiPort}";
                  extraConfig = ''
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  '';
                };
              };
            });
        };

    # ACME configuration for SSL certificates
    security.acme =
      mkIf
        (
          cfg.acmeMail != null
          && (cfg.grafanaHost != null || cfg.prometheusHost != null || cfg.lokiHost != null)
        )
        {
          acceptTerms = true;
          defaults.email = cfg.acmeMail;
        };

    # Simple firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts =
        [
          cfg.grafanaPort
          cfg.lokiPort
          cfg.prometheusPort
        ]
        ++ (optionals (cfg.grafanaHost != null || cfg.prometheusHost != null || cfg.lokiHost != null) [
          80
          443
        ]);
    };

    # Ensure service dependencies
    systemd.services = {
      grafana.after = [ "loki.service" ];
      promtail.after = [ "loki.service" ];
    };
  };
}
