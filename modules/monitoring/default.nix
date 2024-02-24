{ pkgs, config, ... }:

{
  imports = [
    ./grafana.nix
    ./loki.nix
    ./prometheus.nix
    ./promtail.nix
  ];
}
