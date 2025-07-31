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
      volumes = [ "/var/lib/audiotranscriber/data:/app/data" ];
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
      backend = "docker"; # Podman is the default backend.
      containers = {
        audiotranscriber-nginx = {
          image = cfg.nginx-image;
          dependsOn = [ "audiotranscriber-app" ];
          ports = [ "91:80" ];
          extraOptions = [ "--network=audiotranscriber-net" ];
        };

        audiotranscriber-app = {
          image = cfg.app-image;
          ports = [ "8001:3000" ];
          extraOptions = [
            "--network=audiotranscriber-net"
            "--pull=always"
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
      };
    };
  };
}
