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

    # Authentication Options
    grafanaAuth = {
      adminUser = mkOption {
        type = types.str;
        default = "admin";
        description = "Grafana admin username";
      };

      adminPasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing admin password (SOPS secret)";
      };

      adminEmail = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "admin@example.com";
        description = "Admin email address";
      };

      disableSignup = mkOption {
        type = types.bool;
        default = true;
        description = "Prevent new user registration";
      };

      secretKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to secret key file for session signing (SOPS secret)";
      };
    };

    prometheusAuth = {
      webConfigFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Web config file for Prometheus basic auth";
      };
    };
  };

  config = mkIf cfg.enable {
    # Loki - Log aggregation
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_port = cfg.lokiPort;
          grpc_listen_port = cfg.lokiPort + 1000; # Use lokiPort + 1000 for GRPC (e.g., 4100 for GRPC when HTTP is 3100)
        };

        # Single-process mode configuration
        target = "all";

        # Disable structured metadata to avoid schema v13 requirement
        limits_config = {
          allow_structured_metadata = false;
        };

        # Configure for single-process mode without external dependencies
        memberlist = {
          join_members = [ ];
        };

        common = {
          path_prefix = "/var/lib/loki";
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
          replication_factor = 1;
          ring = {
            instance_addr = "127.0.0.1";
            kvstore = {
              store = "inmemory";
            };
          };
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
        security =
          {
            admin_user = cfg.grafanaAuth.adminUser;
            admin_password = "admin"; # TODO: Use SOPS secret file
            disable_initial_admin_creation = false;
          }
          // optionalAttrs (cfg.grafanaAuth.adminEmail != null) { admin_email = cfg.grafanaAuth.adminEmail; };
        users = {
          allow_sign_up = !cfg.grafanaAuth.disableSignup;
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
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "server-health";
              type = "file";
              options.path = "/var/lib/grafana/dashboards";
              updateIntervalSeconds = 30;
              allowUiUpdates = true;
              disableDeletion = false;
            }
          ];
        };
      };
    };

    # Node Exporter - System metrics
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd"
        "textfile"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "stat"
      ];
    };

    # Prometheus - Metrics collection
    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      # webConfigFile = mkIf (cfg.prometheusAuth.webConfigFile != null) cfg.prometheusAuth.webConfigFile;
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.prometheusPort}" ]; } ];
        }
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
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

    # Dashboard files setup
    systemd.tmpfiles.rules = [ "d /var/lib/grafana/dashboards 0755 grafana grafana -" ];

    environment.etc = {
      "grafana/dashboards/server-essentials.json" = {
        text = builtins.readFile ./dashboards/server-essentials.json;
        mode = "0644";
      };
      "grafana/dashboards/docker-health.json" = {
        text = builtins.readFile ./dashboards/docker-health.json;
        mode = "0644";
      };
      "grafana/dashboards/system-logs.json" = {
        text = builtins.readFile ./dashboards/system-logs.json;
        mode = "0644";
      };
    };

    # Nginx virtual hosts for monitoring services
    services.nginx =
      mkIf (cfg.grafanaHost != null || cfg.prometheusHost != null || cfg.lokiHost != null)
        {
          enable = true;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;
          virtualHosts =
            (mkIf (cfg.grafanaHost != null) {
              "${cfg.grafanaHost}" = {
                forceSSL = true;
                enableACME = true;
                locations."/".proxyPass = "http://127.0.0.1:${toString cfg.grafanaPort}";
                locations."/".proxyWebsockets = true;
              };
            })
            // (mkIf (cfg.prometheusHost != null) {
              "${cfg.prometheusHost}" = {
                forceSSL = true;
                enableACME = true;
                locations."/".proxyPass = "http://127.0.0.1:${toString cfg.prometheusPort}";
              };
            })
            // (mkIf (cfg.lokiHost != null) {
              "${cfg.lokiHost}" = {
                forceSSL = true;
                enableACME = true;
                locations."/".proxyPass = "http://127.0.0.1:${toString cfg.lokiPort}";
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
      grafana.after = [
        "loki.service"
        "grafana-dashboard-setup.service"
      ];
      promtail.after = [ "loki.service" ];

      # Copy dashboard files to Grafana directory
      grafana-dashboard-setup = {
        description = "Setup Grafana dashboards";
        wantedBy = [ "multi-user.target" ];
        before = [ "grafana.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/grafana/dashboards";
          ExecStart = [
            "${pkgs.coreutils}/bin/cp /etc/grafana/dashboards/server-essentials.json /var/lib/grafana/dashboards/"
            "${pkgs.coreutils}/bin/cp /etc/grafana/dashboards/docker-health.json /var/lib/grafana/dashboards/"
            "${pkgs.coreutils}/bin/cp /etc/grafana/dashboards/system-logs.json /var/lib/grafana/dashboards/"
          ];
          User = "grafana";
          Group = "grafana";
        };
      };
    };
  };
}
