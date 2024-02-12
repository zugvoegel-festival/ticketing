{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.pretix;
in
{
  options.zugvoegel.services.pretix = {
    # Define option to enable the pretix config
    enable = mkEnableOption "Pretix ticketing service";

    # Define option to set the host
    host = mkOption {
      type = types.str;
      default = null;
      example = "demo.megaclan3000.de";
      description = "Host serving pretix web service";
    };

    instanceName = mkOption {
      type = types.str;
      default = "My Pretix Instance";
      example = "Awesome Pretix";
      description = "Name of the Pretix instance";
    };
    acmeMail = mkOption {
      type = types.str;
      default = null;
      example = "admin@pretix.eu";
      description = "Email for SSL Certificate Renewal";
    };
  };

  config = mkIf cfg.enable {

    sops.secrets.pretix-envfile = { };

    systemd.services.init-pretix-net = {
      description = "Create the network bridge pretix-net";
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
          check=$(${dockercli} network ls | grep "pretix-net" || true)
          if [ -z "$check" ]; then
            ${dockercli} network create pretix-net
          else
            echo "pretix-net already exists in docker"
          fi
        '';
    };

    virtualisation.oci-containers =
      let
          finalImageName = "manulinger/zv-ticketing";

        image-pretix = pkgs.dockerTools.pullImage {
          inherit finalImageName;
          imageName = "manulinger/zv-ticketing";
          imageDigest = "sha256:3d72d3939cb144ca87a523d5f15b59112159c3d053d8605ea49681dac45822d6";
          sha256 = "112vnqvks167kmg66jmd8g7x3xlnjq729zhfdqhl301fx6dxzmya";
          finalImageTag = "final";
        };
      in

      {
        backend = "docker"; # Podman is the default backend.
        containers = {
          redis = {
            image = "redis:7.2.3";
            extraOptions = [ "--network=pretix-net" ];
          };

          postgresql = {
            image = "postgres:16.1";
            extraOptions = [ "--network=pretix-net" ];
            environment = {
              POSTGRES_HOST_AUTH_METHOD = "trust";
              POSTGRES_DB = "pretix";
            };
          };

          pretix =
            let
              pretix-config = pkgs.writeTextFile {
                name = "pretix.cfg";
                text = pkgs.lib.generators.toINI { } {
                  pretix = {
                    instance_name = "${cfg.instanceName}";
                    url = "https://${cfg.host}";
                    currency = "EUR";
                    # ; DO NOT change the following value, it has to be set to the location of the
                    # ; directory *inside* the docker container
                    datadir = "/data";
                    trust_x_forwarded_for = "on";
                    trust_x_forwarded_proto = "on";
                  };

                  database = {
                    backend = "postgresql";
                    name = "pretix";
                    user = "postgres";
                    host = "postgresql";
                  };


                  redis = {
                    location = "redis://redis:6379";
                    # ; Remove the following line if you are unsure about your redis' security
                    # ; to reduce impact if redis gets compromised.
                    sessions = "true";
                  };

                  celery = {
                    backend = "redis://redis:6379/1";
                    broker = "redis://redis:6379/2";
                  };
                };
              };
            in

            {
              # imageFile = self.packages."x86_64-linux".pretix-cliques; # TODO
              imageFile = image-pretix;
              image = finalImageName;
              volumes = [
                # "/path/on/host:/path/inside/container"
                "${pretix-config}:/etc/pretix/pretix.cfg"
                # "/var/lib/pretix-data/data:/data"
              ];
              environmentFiles = [ config.sops.secrets.pretix-envfile.path ];
              ports = [ "12345:80" ];
              extraOptions = [ "--network=pretix-net" ];
            };
        };
      };

    security.acme = {
      acceptTerms = true;
      defaults.email = "${cfg.acmeMail}";
    };

    # nginx reverse proxy
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.host}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:12345";
      };
    };
  };
}

