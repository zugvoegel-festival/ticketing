{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.zugvoegel.services.observability;
in
{
  options.zugvoegel.services.observability = {
    enable = mkEnableOption "Grafana Stack (LGTM) for complete observability";

    host = mkOption {
      type = types.str;
      default = "gucken.loco.vision";
      description = "Hostname for Grafana web interface";
    };

    acmeMail = mkOption {
      type = types.str;
      default = "webmaster@zugvoegelfestival.org";
      description = "Email for ACME certificate generation";
    };

    dataPath = mkOption {
      type = types.str;
      default = "/var/lib/observability";
      description = "Base path for observability data";
    };

    retention = {
      loki = mkOption {
        type = types.str;
        default = "30d";
        description = "Loki log retention period";
      };

      mimir = mkOption {
        type = types.str;
        default = "15d";
        description = "Mimir metrics retention period";
      };

      tempo = mkOption {
        type = types.str;
        default = "7d";
        description = "Tempo traces retention period";
      };
    };

    grafana = {
      defaultDashboards = mkEnableOption "Install default dashboards for common services" // {
        default = true;
      };
    };

    prometheus = {
      enable = mkEnableOption "Enable Prometheus for metrics collection" // {
        default = true;
      };

      scrapeInterval = mkOption {
        type = types.str;
        default = "15s";
        description = "Prometheus scrape interval";
      };
    };
  };

  config = mkIf cfg.enable {
    # SOPS secrets configuration
    sops.secrets.grafana-admin-password = {
      sopsFile = ../../secrets/secrets.yaml;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    sops.secrets.grafana-secret-key = {
      sopsFile = ../../secrets/secrets.yaml;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    # Create data directories
    systemd.tmpfiles.rules =
      [
        "d ${cfg.dataPath} 0755 root root -"
        "d ${cfg.dataPath}/loki 0755 loki loki -"
        "d ${cfg.dataPath}/grafana 0755 grafana grafana -"
        "d ${cfg.dataPath}/tempo 0755 tempo tempo -"
        "d ${cfg.dataPath}/mimir 0755 mimir mimir -"
        "d ${cfg.dataPath}/prometheus 0755 prometheus prometheus -"
      ]
      ++ (lib.optionals cfg.grafana.defaultDashboards [
        "d /var/lib/grafana/dashboards 0755 grafana grafana -"
      ]);

    # Loki - Log aggregation
    services.loki = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 3100;
          log_level = "info";
        };

        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 999999;
          chunk_retain_period = "30s";
        };

        schema_config = {
          configs = [
            {
              from = "2023-01-01";
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

        storage_config = {
          boltdb_shipper = {
            active_index_directory = "${cfg.dataPath}/loki/boltdb-shipper-active";
            cache_location = "${cfg.dataPath}/loki/boltdb-shipper-cache";
            cache_ttl = "24h";
            shared_store = "filesystem";
          };
          filesystem = {
            directory = "${cfg.dataPath}/loki/chunks";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          retention_period = cfg.retention.loki;
        };

        chunk_store_config = {
          max_look_back_period = "0s";
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };

        compactor = {
          working_directory = "${cfg.dataPath}/loki/boltdb-shipper-compactor";
          shared_store = "filesystem";
        };
      };
    };

    # Tempo - Distributed tracing
    services.tempo = {
      enable = true;
      settings = {
        server = {
          http_listen_port = 3200;
        };

        distributor = {
          receivers = {
            jaeger = {
              protocols = {
                thrift_http = {
                  endpoint = "0.0.0.0:14268";
                };
                grpc = {
                  endpoint = "0.0.0.0:14250";
                };
              };
            };
            zipkin = {
              endpoint = "0.0.0.0:9411";
            };
            otlp = {
              protocols = {
                http = {
                  endpoint = "0.0.0.0:4318";
                };
                grpc = {
                  endpoint = "0.0.0.0:4317";
                };
              };
            };
          };
        };

        ingester = {
          trace_idle_period = "10s";
          max_block_bytes = 1 _000_000;
          max_block_duration = "5m";
        };

        compactor = {
          compaction = {
            compaction_window = "1h";
            max_block_bytes = 100 _000_000;
            block_retention = cfg.retention.tempo;
            compacted_block_retention = "10m";
          };
        };

        storage = {
          trace = {
            backend = "local";
            local = {
              path = "${cfg.dataPath}/tempo/traces";
            };
          };
        };
      };
    };

    # Prometheus - Metrics collection (if enabled)
    services.prometheus = mkIf cfg.prometheus.enable {
      enable = true;
      port = 9090;
      dataDir = "${cfg.dataPath}/prometheus";

      globalConfig = {
        scrape_interval = cfg.prometheus.scrapeInterval;
        evaluation_interval = "15s";
      };

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "localhost:9090" ]; } ];
        }
        {
          job_name = "loki";
          static_configs = [ { targets = [ "localhost:3100" ]; } ];
        }
        {
          job_name = "tempo";
          static_configs = [ { targets = [ "localhost:3200" ]; } ];
        }
        {
          job_name = "grafana";
          static_configs = [ { targets = [ "localhost:3000" ]; } ];
        }
        {
          job_name = "node-exporter";
          static_configs = [ { targets = [ "localhost:9100" ]; } ];
        }
        # Add scraping for existing services
        {
          job_name = "pretix";
          static_configs = [ { targets = [ "localhost:8080" ]; } ];
          metrics_path = "/metrics";
        }
      ];

      rules = [
        ''
          groups:
            - name: system
              rules:
                - alert: HighCPUUsage
                  expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU usage detected"
                    description: "CPU usage is above 80% for more than 5 minutes"

                - alert: HighMemoryUsage
                  expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
                  for: 5m
                  labels:
                    severity: critical
                  annotations:
                    summary: "High memory usage detected"
                    description: "Memory usage is above 90% for more than 5 minutes"

                - alert: DiskSpaceLow
                  expr: (node_filesystem_size_bytes{fstype!="tmpfs"} - node_filesystem_free_bytes{fstype!="tmpfs"}) / node_filesystem_size_bytes{fstype!="tmpfs"} * 100 > 85
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Disk space running low"
                    description: "Disk usage is above 85% for more than 5 minutes"
        ''
      ];

      # Node Exporter for system metrics
      exporters.node = {
        enable = true;
        port = 9100;
        enabledCollectors = [
          "systemd"
          "processes"
          "interrupts"
          "ksmd"
          "logind"
          "meminfo_numa"
          "mountstats"
          "network_route"
          "systemd"
          "tcpstat"
          "wifi"
        ];
      };
    };

    # Grafana - Visualization and dashboards
    services.grafana = {
      enable = true;
      settings = {
        server = {
          domain = cfg.host;
          http_port = 3000;
          http_addr = "127.0.0.1";
          root_url = "https://${cfg.host}";
        };

        database = {
          type = "sqlite3";
          path = "${cfg.dataPath}/grafana/grafana.db";
        };

        security = {
          admin_password = config.sops.secrets.grafana-admin-password.path;
          secret_key = config.sops.secrets.grafana-secret-key.path;
        };

        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };

        users = {
          allow_sign_up = false;
          auto_assign_org = true;
          auto_assign_org_role = "Viewer";
        };

        auth.anonymous = {
          enabled = false;
        };

        log = {
          mode = "console file";
          level = "info";
        };

        alerting = {
          enabled = true;
        };
      };

      provision = {
        enable = true;

        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
            isDefault = true;
            uid = "prometheus";
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://localhost:3100";
            uid = "loki";
          }
          {
            name = "Tempo";
            type = "tempo";
            access = "proxy";
            url = "http://localhost:3200";
            uid = "tempo";
            jsonData = {
              tracesToLogs = {
                datasourceUid = "loki";
                tags = [
                  "job"
                  "instance"
                ];
                mappedTags = [
                  {
                    key = "service.name";
                    value = "service";
                  }
                ];
                mapTagNamesEnabled = false;
                spanStartTimeShift = "1h";
                spanEndTimeShift = "1h";
                filterByTraceID = false;
                filterBySpanID = false;
              };
              serviceMap = {
                datasourceUid = "prometheus";
              };
              nodeGraph = {
                enabled = true;
              };
            };
          }
        ];

        dashboards.settings.providers = mkIf cfg.grafana.defaultDashboards [
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

    # Promtail - Log shipping to Loki
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        positions = {
          filename = "${cfg.dataPath}/loki/positions.yaml";
        };

        clients = [ { url = "http://localhost:3100/loki/api/v1/push"; } ];

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
              {
                source_labels = [ "__journal__hostname" ];
                target_label = "hostname";
              }
            ];
          }
          {
            job_name = "nginx";
            static_configs = [
              {
                targets = [ "localhost" ];
                labels = {
                  job = "nginx";
                  host = config.networking.hostName;
                  __path__ = "/var/log/nginx/*.log";
                };
              }
            ];
            pipeline_stages = [
              {
                match = {
                  selector = ''{job="nginx"}'';
                  stages = [
                    {
                      regex = {
                        expression = ''^(?P<remote_addr>[\w\.]+) - (?P<remote_user>[^ ]*) \[(?P<time_local>[^\]]*)\] "(?P<method>[^ ]*) (?P<request>[^ ]*) (?P<protocol>[^ ]*)" (?P<status>[\d]+) (?P<body_bytes_sent>[\d]+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'';
                      };
                    }
                    {
                      labels = {
                        method = "";
                        status = "";
                      };
                    }
                  ];
                };
              }
            ];
          }
        ];
      };
    };

    # Copy default dashboards
    environment.etc = mkIf cfg.grafana.defaultDashboards {
      "grafana-dashboards/node-exporter.json".source = ./dashboards/node-exporter.json;
      "grafana-dashboards/loki-logs.json".source = ./dashboards/loki-logs.json;
      "grafana-dashboards/system-overview.json".source = ./dashboards/system-overview.json;
    };

    # Nginx reverse proxy configuration
    services.nginx = {
      enable = true;
      virtualHosts."${cfg.host}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };

    # ACME configuration
    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.acmeMail;
    };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [
      3000 # Grafana
      3100 # Loki
      3200 # Tempo
      9090 # Prometheus
      9100 # Node Exporter
      9080 # Promtail
      14268 # Jaeger HTTP
      14250 # Jaeger gRPC
      9411 # Zipkin
      4317 # OTLP gRPC
      4318 # OTLP HTTP
    ];

    # Systemd services dependencies
    systemd.services = {
      grafana.after = [
        "prometheus.service"
        "loki.service"
      ];
      grafana.wants = [
        "prometheus.service"
        "loki.service"
      ];

      promtail.after = [ "loki.service" ];
      promtail.wants = [ "loki.service" ];
    };
  };
}
