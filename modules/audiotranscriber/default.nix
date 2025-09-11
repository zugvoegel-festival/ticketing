{ config, lib, ... }:
with lib;
let
  cfg = config.zugvoegel.services.audiotranscriber;
in
{
  options.zugvoegel.services.audiotranscriber = {
    enable = mkEnableOption "audio transcriber service";
    host = mkOption {
      type = types.str;
      default = null;
      example = "demo.megaclan3000.de";
      description = "Host serving service";
    };

    app-image = mkOption {
      type = types.str;
      default = null;
      example = "dockeruser/repository-name:tag";
      description = "Docker image with tag";
    };

    nginx-image = mkOption {
      type = types.str;
      default = null;
      example = "dockeruser/repository-name:tag";
      description = "Docker image with tag";
    };
    acmeMail = mkOption {
      type = types.str;
      default = null;
      example = "admin@pretix.eu";
      description = "Email for SSL Certificate Renewal";
    };
  };

  config = mkIf cfg.enable {

    sops.secrets.audiotranscriber-envfile = { };

    systemd.services.init-audiotranscriber-data-dir = {
      description = "Create audiotranscriber data directory";
      wantedBy = [ "multi-user.target" ];
      before = [ "docker-audiotranscriber-app.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /var/lib/audiotranscriber/data
        chown -R 1000:1000 /var/lib/audiotranscriber/data
        chmod -R 755 /var/lib/audiotranscriber/data
      '';
    };

    systemd.services.init-audiotranscriber-net = {
      description = "Create the network bridge audiotranscriber-net";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";
      script =
        let
          dockercli = "${config.virtualisation.docker.package}/bin/docker";
        in
        ''
          # Put a true at the end to prevent getting non-zero return code,
          # which will crash the whole service.
          check=$(${dockercli} network ls | grep "audiotranscriber-net" || true)
          if [ -z "$check" ]; then
            ${dockercli} network create audiotranscriber-net
          else
            echo "audiotranscriber-net already exists in docker"
          fi
        '';
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {

        audiotranscriber-app = {
          image = cfg.app-image;
          ports = [ "8001:3000" ];
          volumes = [ "/var/lib/audiotranscriber/data:/app/data" ];
          environmentFiles = [ config.sops.secrets.audiotranscriber-envfile.path ];
          extraOptions = [
            "--pull=always"
            "--network=audiotranscriber-net"
          ];
        };
      };
    };

    # nginx reverse proxy
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.host}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://localhost:8001";
        locations."/".extraConfig = ''
          client_max_body_size 1024M;
        '';
      };
    };
  };
}
