{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.zugvoegel.services.backup;
in
{

  imports = [ ./hardware-configuration.nix ];
  zugvoegel = {
    services.bank-automation.enable = false;

    services.vikunja = {
      enable = true;
      smtpPort = 587;
    };

    services.pretix = {
      enable = true;
      host = "tickets.zugvoegelfestival.org";
      instanceName = "Zugvoegel Ticketshop";
      pretixImage = "manulinger/zv-ticketing:pretix-custom-cliques";
      acmeMail = "webmaster@zugvoegelfestival.org";
      pretixDataPath = "/var/lib/pretix-data/data";
      port = 12345;
    };
    services.schwarmplaner = {
      enable = true;
      host = "schwarmplaner.zugvoegelfestival.org";
      apiHost = "api.zugvoegelfestival.org";
      acmeMail = "webmaster@zugvoegelfestival.org";
      nginxPort = 3301;
      mysqlPort = 3302;
      apiPort = 3304;
      frontendPort = 3303;
    };

    services.audiotranscriber = {
      enable = true;
      host = "audiotranscriber-test.loco.vision";
      app-image = 
        let envVersion = builtins.getEnv "AUDIOTRANSCRIBER_VERSION";
        in "manulinger/audio-transcriber:test";
      acmeMail = "webmaster@zugvoegelfestival.org";
      port = 8001;
    };

    services.minio = {
      enable = true;
      host = "minio-test.loco.vision";
      consoleHost = "minio-console-test.loco.vision";
      acmeMail = "webmaster@zugvoegelfestival.org";
      port = 9000;
      consolePort = 9001;
    };

    services.backup = {
      enable = true;
      s3BaseUrl = "s3:https://s3.us-west-004.backblazeb2.com";
      bucketPrefix = "zv-backups";
      schedule = "03:00"; # Default backup time

      services = {
        # Pretix PostgreSQL database backup
        pretix-db = {
          enable = true;
          type = "database";
          dbType = "postgresql";
          containerName = "postgresql";
          dbUser = "postgres";
          dumpPath = "/var/lib/backups/pretix-db";
          schedule = "02:30"; # Earlier than files to ensure DB consistency
        };

        # Pretix data files backup
        pretix-data = {
          enable = true;
          type = "files";
          paths = [ "/var/lib/pretix-data/data" ];
          excludePaths = [
            "*/cache/*"
            "*/tmp/*"
            "*.log"
          ];
          schedule = "03:00";
        };

        # Schwarmplaner MySQL database backup
        schwarmplaner-db = {
          enable = true;
          type = "database";
          dbType = "mysql";
          containerName = "schwarmplaner-db";
          dbUser = "root";
          dbPassword = "HurraWirFliegen24";
          dbName = "schwarmDatabase";
          dumpPath = "/var/lib/backups/schwarmplaner-db";
          schedule = "02:45";
        };

        # Audio Transcriber data backup
        audiotranscriber-pwa = {
          enable = true;
          type = "files";
          paths = [ "/var/lib/audiotranscriber-pwa/data" ];
          excludePaths = [
            "*/temp/*"
            "*/processing/*"
            "*.tmp"
          ];
          schedule = "03:15";
        };

        # MinIO data backup
        minio = {
          enable = true;
          type = "files";
          paths = [ "/var/lib/minio/data" ];
          excludePaths = [
            "*/.minio.sys/tmp/*"
            "*/multipart/*"
          ];
          schedule = "03:30";
        };
      };
    };

    services.monitoring = {
      enable = true;
      grafanaHost = "grafana-test.loco.vision";
      #    prometheusHost = "prometheus.loco.vision";
      #   lokiHost = "loki.loco.vision";
      acmeMail = "webmaster@zugvoegelfestival.org";
      grafanaPort = 4000;
      lokiPort = 4001;
      prometheusPort = 4002;
      promtailPort = 4003;

      # Authentication configuration
      grafanaAuth = {
        adminUser = "admin";
        adminEmail = "webmaster@zugvoegelfestival.org";
        disableSignup = true;
      };
    };
  };

  sops.defaultSopsFile = ./secrets/secrets.yaml; # "Install" git

  # System packages and admin scripts
  environment.systemPackages = [
    pkgs.git
  ];

  # Time zone and internationalisation
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Networking and SSH
  networking = {
    firewall.enable = true;
    firewall.interfaces.eth0.allowedTCPPorts = [
      80
      443
    ];
    # Allow Docker containers to access MinIO
    firewall.trustedInterfaces = [
      "docker0"
      "br-+"
    ];
    firewall.allowedTCPPorts = [ 9000 ];
    hostName = "pretix-server-01";
    interfaces.eth0.useDHCP = true;
  };

  # User configuration
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILSJJs01RqXS6YE5Jf8LUJoJVBxFev3R18FWXJyLeYJE"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIm11sPvZgi/QiLaB61Uil4bJzpoz0+AWH2CHH2QGiPm" # Netcup demo key github
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGCmCMCN1BuYW2xCVTdXlNIILbJABp0MPgjc2rYMq9K" # Manu
  ];

  # Enable ssh
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "yes";
  };

  system.stateVersion = "23.05";
}
