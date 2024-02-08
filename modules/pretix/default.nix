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
    fromMail = mkOption {
      type = types.str;
      default = null;
      example = "no-reply@pretix.eu";
      description = "From Email from which tickets will be send.";
    };
    fromMailPassword = mkOption {
      type = types.str;
      default = null;
      example = "###########";
      description = "Password of you mail";
    };
    fromMailUser = mkOption {
      type = types.str;
      default = null;
      example = "mailuser";
      description = "User of you mail";
    };
    fromMailPort = mkOption {
      type = types.integer;
      default = 587;
      example = 587;
      description = "SMTP Port of you mail";
    };
    fromMMailTLS = mkOption {
      type = types.str;
      default = "off";
      example = "off";
      description = "on/off to activate/deactivate";
    };
    fromMailSSL = mkOption {
      type = types.str;
      default = "off";
      example = "off";
      description = "on/off to activate/deactivate";
    };
  };

  config = mkIf cfg.enable {

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
        image-pretix = pkgs.dockerTools.pullImage {
          imageName = "pretix/standalone";
          imageDigest = "sha256:f4e62cf46db9c72a5adc1fdc3fb6005f170e17e69c65ccf1d0760b6f43ffe995";
          sha256 = "17jszn49wn7mj8zrrai9z55yh6n83c726hdnjhasvc9c857lssxr";
          finalImageName = "pretix/standalone";
          finalImageTag = "2023.10.0";
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
                    instance_name = ${cfg.instance_name};
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
                    # ; Replace with the password you chose above
                    password = config.sops.secrets.postgressPassword.path;
                    # ; In most docker setups, 172.17.0.1 is the address of the docker host. Adjust
                    # ; this to wherever your database is running, e.g. the name of a linked container.
                    host = "postgresql";
                  };

                  mail = {
                    # ; See config file documentation for more options
                    from = "${cfg.fromMail}";
                    host = "${cfg.fromMailHost}";
                    user = "${cfg.fromMailUser}";
                    password = "${cfg.fromMailPassword}";
                    port = "${cfg.fromMailPort}";
                    tls = "${cfg.fromMMailTLS}";
                    ssl = "${cfg.fromMMailSSL}";
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
              image = "pretix/standalone";
              volumes = [
                # "/path/on/host:/path/inside/container"
                "${pretix-config}:/etc/pretix/pretix.cfg"
                # "/var/lib/pretix-data/data:/data"
              ];

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

