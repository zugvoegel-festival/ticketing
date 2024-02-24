{ pkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
  ];
  zugvoegel =
    {
      services.bank-automation.enable = true;

      services.pretix = {
        # Actually use our module
        enable = true;
        # Set the host
        host = "tickets.loco.vision";

        instanceName = "Zugvoegel Ticketshop";
        pretixImage = "manulinger/zv-ticketing:pip";
        # Set the acme mail
        acmeMail = "pretix-admin@zugvoegelfestival.org";
      };
      services.backup = {
        enable = true;
        backupDirs = [ "/srv/pretix" ];
      };
    };

  sops.defaultSopsFile = ./secrets/secrets.yaml;

  # "Install" git
  environment.systemPackages = [ pkgs.git ];

  # Time zone and internationalisation
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Networking and SSH
  networking = {
    firewall.enable = true;
    firewall.interfaces.eth0.allowedTCPPorts = [ 80 443 ];
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
