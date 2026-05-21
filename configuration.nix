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
      # SSH pubkey for pretix GitHub Actions (private key → SSH_PRIVATE_KEY in ticketing repo).
      # Generate: ssh-keygen -t ed25519 -C "github-actions-pretix" -f /tmp/pretix-deploy-key -N ""
      deployAuthorizedKeys = [ ];
    };

    services.schwarmplaner = {
      enable = true;

      # SSH pubkeys for the dedicated `deploy` user used by GitHub Actions
      # workflows in the schwarmplaner repo. The private half lives as the
      # SSH_PRIVATE_KEY repo secret.
      deployAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/42RUXxK9qOKr5yOjOL9rNpeEMuaTQ8zJjsHi5nRHa github-actions-schwarmplaner"
      ];
    };

    services.trees99 = {
      enable = true;

      # SSH pubkey for 99trees GitHub Actions (private key → SSH_PRIVATE_KEY secret).
      deployAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCCjSkw16myEa5z5BW+Ol/0ACNFgXYC4JonMEpkXnaD github-actions-99trees"
      ];
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
      acmeMail = "webmaster@zugvoegelfestival.org";
      grafanaPort = 4000;
      lokiPort = 4001;
      prometheusPort = 4002;
      alloyPort = 4003;
      openFirewall = false;

      grafanaAuth = {
        adminUser = "admin";
        adminEmail = "webmaster@zugvoegelfestival.org";
        disableSignup = true;
      };
    };
  };

  sops.defaultSopsFile = ./secrets/secrets.yaml;

  environment.systemPackages = [
    pkgs.git
  ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

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

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILSJJs01RqXS6YE5Jf8LUJoJVBxFev3R18FWXJyLeYJE"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIm11sPvZgi/QiLaB61Uil4bJzpoz0+AWH2CHH2QGiPm" # Netcup demo key github
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGCmCMCN1BuYW2xCVTdXlNIILbJABp0MPgjc2rYMq9K" # Manu
  ];

  # Shared deploy user for app CI (schwarmplaner, 99trees, pretix). Pubkeys come from
  # each service's deployAuthorizedKeys; sudo rules stay in the service modules.
  users.users.deploy = let
    deployKeys =
      config.zugvoegel.services.pretix.deployAuthorizedKeys
      ++ config.zugvoegel.services.schwarmplaner.deployAuthorizedKeys
      ++ config.zugvoegel.services.trees99.deployAuthorizedKeys;
  in
  lib.mkIf (deployKeys != [ ]) {
    isNormalUser = true;
    description = "GitHub Actions deployment user";
    home = "/var/lib/deploy";
    createHome = true;
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = lib.unique deployKeys;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };

  # Automatic store GC and bounded boot generations
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  boot.loader.grub.configurationLimit = 5;

  system.stateVersion = "23.05";
}
