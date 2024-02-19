{ lib, pkgs, config, bank-automation, ... }:
with lib;
let cfg = config.zugvoegel.services.bank-automation;
in
{
  options.zugvoegel.services.bank-automation = {
    enable = mkEnableOption "bank automation service";
  };

  config = mkIf cfg.enable {

    sops.secrets.bank-envfile = { };

    # Run daily
    systemd.timers."bank-automation" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "bank-automation.service";
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Service for the bank-automation
    systemd.services.bank-automation = {
      description = "Start bank-automation";
      after = [ "network.target" ];

      environmentFile = config.sops.secrets.bank-envfile.path;

      serviceConfig = {
        Type = "oneshot";
        PermissionsStartOnly = true;
        LimitNPROC = 512;
        LimitNOFILE = 1048576;
        CapabilityBoundingSet = "cap_net_bind_service";
        AmbientCapabilities = "cap_net_bind_service";
        NoNewPrivileges = true;
        DynamicUser = true;
        ExecStart = "${bank-automation.defaultPackage.x86_64-linux}/bin/bank-automation";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
