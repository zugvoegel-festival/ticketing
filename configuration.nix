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

    services.pretix = {
      enable = true;
      host = "tickets.zugvoegelfestival.org";
      instanceName = "Zugvoegel Ticketshop";
      pretixImage = "manulinger/zv-ticketing:pretix";
      acmeMail = "webmaster@zugvoegelfestival.org";
      pretixDataPath = "/var/lib/pretix-data/data";
      port = 12345;
    };
    services.schwarmplaner = {
      enable = true;

      # SSH pubkeys for the dedicated `deploy` user used by GitHub Actions
      # workflows in the schwarmplaner repo. The private half lives as the
      # SSH_PRIVATE_KEY repo secret.
      deployAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/42RUXxK9qOKr5yOjOL9rNpeEMuaTQ8zJjsHi5nRHa github-actions-schwarmplaner"
      ];

      instances = {
        prod = {
          host = "schwarmplaner.zugvoegelfestival.org";
          app-image = "manulinger/schwarmplaner:prod-latest";
          acmeMail = "webmaster@zugvoegelfestival.org";
          port = 3303;
        };
        test = {
          host = "test.schwarmplaner.zugvoegelfestival.org";
          app-image = "manulinger/schwarmplaner:test-latest";
          acmeMail = "webmaster@zugvoegelfestival.org";
          port = 3313;
        };
      };
    };

    services.trees99 = {
      enable = true;

      # SSH pubkey for 99trees GitHub Actions (private key → SSH_PRIVATE_KEY secret).
      # Generate: ssh-keygen -t ed25519 -C "github-actions-99trees" -f /tmp/99trees-deploy-key -N ""
      deployAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCCjSkw16myEa5z5BW+Ol/0ACNFgXYC4JonMEpkXnaD github-actions-99trees"
      ];

      instances = {
        prod = {
          host = "trees.loco.vision";
          app-image = "manulinger/99trees:prod-latest";
          acmeMail = "webmaster@zugvoegelfestival.org";
          port = 3323;
        };
      };
    };

    services.wedding-catcher = {
      enable = false;
      host = "catch-a-wedding.loco.vision";
      image = "manulinger/wedding-catcher:latest";
      acmeMail = "webmaster@zugvoegelfestival.org";
      port = 3305;
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

        # Schwarmplaner now ships a single Docker container with an
        # SQLite file mounted at /var/lib/schwarmplaner-<env>/data. The
        # daily file backups below replace the legacy MySQL dump.
        schwarmplaner-prod = {
          enable = true;
          type = "files";
          paths = [ "/var/lib/schwarmplaner-prod/data" ];
          excludePaths = [
            "*.db-journal"
            "*.db-wal"
            "*.db-shm"
          ];
          schedule = "02:45";
        };

        schwarmplaner-test = {
          enable = true;
          type = "files";
          paths = [ "/var/lib/schwarmplaner-test/data" ];
          excludePaths = [
            "*.db-journal"
            "*.db-wal"
            "*.db-shm"
          ];
          schedule = "02:50";
        };

        trees99-prod = {
          enable = true;
          type = "files";
          paths = [ "/var/lib/99trees-prod/data" ];
          excludePaths = [
            "*.db-journal"
            "*.db-wal"
            "*.db-shm"
          ];
          schedule = "02:55";
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
      openFirewall = false;

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
    firewall.trustedInterfaces = [
      "docker0"
      "br-+"
    ];
    hostName = "pretix-server-01";
    interfaces.eth0.useDHCP = true;
  };

  # User configuration
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILSJJs01RqXS6YE5Jf8LUJoJVBxFev3R18FWXJyLeYJE"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIm11sPvZgi/QiLaB61Uil4bJzpoz0+AWH2CHH2QGiPm" # Netcup demo key github
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGCmCMCN1BuYW2xCVTdXlNIILbJABp0MPgjc2rYMq9K" # Manu
  ];

  # Note: GitHub Actions deploy keys (schwarmplaner, 99trees) are NOT root keys.
  # They are wired into the shared unprivileged "deploy" user with narrowly
  # scoped sudoers via services.schwarmplaner.deployAuthorizedKeys and
  # services.trees99.deployAuthorizedKeys.

  # Enable ssh
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };

  system.stateVersion = "23.05";
}
