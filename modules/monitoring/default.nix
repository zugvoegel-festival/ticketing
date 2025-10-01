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

    loki = {
      enable = mkEnableOption "Loki log aggregation service";
      port = mkOption {
        type = types.port;
        default = 3100;
        description = "Port for Loki HTTP API";
      };
      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/loki";
        description = "Data directory for Loki";
      };
    };

    grafana = {
      enable = mkEnableOption "Grafana dashboard service";
      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port for Grafana web interface";
      };
      adminPassword = mkOption {
        type = types.str;
        default = "admin123";
        description = "Admin password for Grafana";
      };
      provisionDashboards = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic dashboard provisioning";
      };
    };

    prometheus = {
      enable = mkEnableOption "Prometheus metrics collection service";
      port = mkOption {
        type = types.port;
        default = 9090;
        description = "Port for Prometheus web interface";
      };
      retention = mkOption {
        type = types.str;
        default = "200h";
        description = "How long to retain metrics data";
      };
    };

    promtail = {
      enable = mkEnableOption "Promtail log collection service";
      port = mkOption {
        type = types.port;
        default = 9080;
        description = "Port for Promtail HTTP server";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for monitoring services";
    };
  };

  config = mkIf cfg.enable {
    # Enable native NixOS services
    services.loki = mkIf cfg.loki.enable {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_port = cfg.loki.port;
          grpc_listen_port = 9096;
        };
        common = {
          instance_addr = "127.0.0.1";
          path_prefix = cfg.loki.dataDir;
          storage = {
            filesystem = {
              chunks_directory = "${cfg.loki.dataDir}/chunks";
              rules_directory = "${cfg.loki.dataDir}/rules";
            };
          };
          replication_factor = 1;
          ring = {
            kvstore = {
              store = "inmemory";
            };
          };
        };
        query_range = {
          results_cache = {
            cache = {
              embedded_cache = {
                enabled = true;
                max_size_mb = 100;
              };
            };
          };
        };
        schema_config = {
          configs = [
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
        };
        ruler = {
          alertmanager_url = "http://localhost:9093";
        };
        analytics = {
          reporting_enabled = false;
        };
      };
      dataDir = cfg.loki.dataDir;
    };

    services.grafana = mkIf cfg.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          http_addr = "127.0.0.1";
        };
        security = {
          admin_user = "admin";
          admin_password = cfg.grafana.adminPassword;
        };
        plugins = {
          enable_alpha = true;
        };
      };
      declarativePlugins = with pkgs.grafanaPlugins; [ grafana-polystat-panel ];
      provision = mkIf cfg.grafana.provisionDashboards {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:${toString cfg.loki.port}";
              isDefault = true;
              editable = true;
              jsonData = {
                maxLines = 1000;
              };
            }
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString cfg.prometheus.port}";
              isDefault = false;
              editable = true;
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "default";
              orgId = 1;
              folder = "";
              type = "file";
              disableDeletion = false;
              updateIntervalSeconds = 10;
              allowUiUpdates = true;
              options = {
                path = "/var/lib/grafana/dashboards";
              };
            }
          ];
        };
      };
    };

    services.prometheus = mkIf cfg.prometheus.enable {
      enable = true;
      port = cfg.prometheus.port;
      listenAddress = "127.0.0.1";
      retentionTime = cfg.retention;
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.prometheus.port}" ]; } ];
        }
        {
          job_name = "audio-transcriber";
          static_configs = [ { targets = [ "audio-transcriber:3000" ]; } ];
          metrics_path = "/api/metrics";
          scrape_interval = "30s";
        }
        {
          job_name = "loki";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.loki.port}" ]; } ];
        }
        {
          job_name = "grafana";
          static_configs = [ { targets = [ "127.0.0.1:${toString cfg.grafana.port}" ]; } ];
        }
      ];
    };

    services.promtail = mkIf cfg.promtail.enable {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.promtail.port;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [ { url = "http://127.0.0.1:${toString cfg.loki.port}/loki/api/v1/push"; } ];
        scrape_configs = [
          # Docker container logs
          {
            job_name = "docker";
            docker_sd_configs = [
              {
                host = "unix:///var/run/docker.sock";
                refresh_interval = "5s";
                filters = [
                  {
                    name = "label";
                    values = [ "logging=promtail" ];
                  }
                ];
              }
            ];
            relabel_configs = [
              {
                source_labels = [ "__meta_docker_container_name" ];
                regex = "/(.*)";
                target_label = "container_name";
              }
              {
                source_labels = [ "__meta_docker_container_log_stream" ];
                target_label = "logstream";
              }
              {
                source_labels = [ "__meta_docker_container_label_com_docker_compose_service" ];
                target_label = "service_name";
              }
            ];
            pipeline_stages = [
              {
                json = {
                  expressions = {
                    level = "level";
                    timestamp = "time";
                    message = "msg";
                    request_id = "requestId";
                    user_id = "userId";
                    method = "method";
                    url = "url";
                    status_code = "statusCode";
                    duration = "duration";
                    type = "type";
                  };
                };
              }
              {
                labels = {
                  level = "";
                  request_id = "";
                  user_id = "";
                  method = "";
                  status_code = "";
                  type = "";
                  service_name = "";
                  container_name = "";
                };
              }
              {
                timestamp = {
                  source = "timestamp";
                  format = "RFC3339";
                };
              }
              {
                output = {
                  source = "message";
                };
              }
            ];
          }
          # Audio-transcriber application logs
          {
            job_name = "audio-transcriber";
            static_configs = [
              {
                targets = [ "localhost" ];
                labels = {
                  job = "audio-transcriber";
                  __path__ = "/var/log/audio-transcriber/*.log";
                };
              }
            ];
            pipeline_stages = [
              {
                json = {
                  expressions = {
                    level = "level";
                    timestamp = "time";
                    message = "msg";
                    request_id = "requestId";
                    user_id = "userId";
                    method = "method";
                    url = "url";
                    status_code = "statusCode";
                    duration = "duration";
                    type = "type";
                    anamnesis_id = "anamnesisId";
                    operation = "operation";
                  };
                };
              }
              {
                labels = {
                  level = "";
                  request_id = "";
                  user_id = "";
                  method = "";
                  status_code = "";
                  type = "";
                  anamnesis_id = "";
                  operation = "";
                };
              }
              {
                timestamp = {
                  source = "timestamp";
                  format = "RFC3339";
                };
              }
              {
                output = {
                  source = "message";
                };
              }
            ];
          }
          # System logs
          {
            job_name = "system";
            static_configs = [
              {
                targets = [ "localhost" ];
                labels = {
                  job = "system";
                  __path__ = "/var/log/syslog";
                };
              }
            ];
            pipeline_stages = [
              {
                regex = {
                  expression = "^(?P<timestamp>\\S+\\s+\\d+\\s+\\d+:\\d+:\\d+)\\s+(?P<hostname>\\S+)\\s+(?P<service>\\S+?)(\\[(?P<pid>\\d+)\\])?:\\s*(?P<message>.*)$";
                };
              }
              {
                labels = {
                  hostname = "";
                  service = "";
                  pid = "";
                };
              }
              {
                timestamp = {
                  source = "timestamp";
                  format = "Jan _2 15:04:05";
                };
              }
            ];
          }
        ];
      };
    };

    # Configure systemd service ordering
    systemd.services = {
      grafana = mkIf cfg.grafana.enable {
        after = mkIf cfg.loki.enable [ "loki.service" ];
        wants = mkIf cfg.loki.enable [ "loki.service" ];
      };
      promtail = mkIf cfg.promtail.enable {
        after = mkIf cfg.loki.enable [ "loki.service" ];
        wants = mkIf cfg.loki.enable [ "loki.service" ];
      };
    };

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts =
        [ ]
        ++ (optional cfg.grafana.enable cfg.grafana.port)
        ++ (optional cfg.loki.enable cfg.loki.port)
        ++ (optional cfg.prometheus.enable cfg.prometheus.port);
    };

    # Ensure data directories exist with proper permissions
    systemd.tmpfiles.rules = [
      (mkIf cfg.loki.enable "d ${cfg.loki.dataDir} 0750 loki loki - -")
      (mkIf cfg.loki.enable "d ${cfg.loki.dataDir}/chunks 0750 loki loki - -")
      (mkIf cfg.loki.enable "d ${cfg.loki.dataDir}/rules 0750 loki loki - -")
      (mkIf cfg.grafana.enable "d /var/lib/grafana/dashboards 0755 grafana grafana - -")
      (mkIf cfg.grafana.enable "C /var/lib/grafana/dashboards/audio-transcriber-dashboard.json 0644 grafana grafana - ${./dashboards/audio-transcriber-dashboard.json}"
      )
    ];
  };
}
