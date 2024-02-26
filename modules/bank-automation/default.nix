{ lib, config, bank-automation, ... }:
with lib;
let cfg = config.zugvoegel.services.bank-automation;
in
{
  options.zugvoegel.services.bank-automation = {
    enable = mkEnableOption "bank automation service";
  };

  config = mkIf cfg.enable {

    sops.secrets.bank-envfile = { };

    # Service for the bank-automation
    systemd.services.bank-automation = {
      description = "Start bank-automation";
      after = [ "network.target" ];

      # Run daily
      systemd.timers."pretix-bank-automation" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          Unit = "pretix-bank-automation.service";
          OnCalendar = "00:05";
          Persistent = true;
        };
      };

      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.secrets.bank-envfile.path;
        PermissionsStartOnly = true;
        LimitNPROC = 512;
        LimitNOFILE = 1048576;
        CapabilityBoundingSet = "cap_net_bind_service";
        AmbientCapabilities = "cap_net_bind_service";
        NoNewPrivileges = true;
        DynamicUser = true;
        ExecStart = "${bank-automation.defaultPackage.x86_64-linux}/bin/pretix-bank-automation";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
