{ ... }:

{
  imports = [
    ./grafana.nix
    ./loki.nix
    ./prometheus.nix
    ./promtail.nix
    ./prometheus_exporter_only.nix
  ];
}
