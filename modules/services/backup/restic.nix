{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.zugvoegel.services.backup;
in
{
  options.zugvoegel.services.backup.restic = {
    # Define option to enable the pretix config
    enable = mkEnableOption "Pretix ticketing service";

    # Define options for restic
    backupDir = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/path/to/backup/directory" ];
      description = "Directories to be backed up using restic";
    };

    resticPasswordFile = mkOption {
      type = types.str;
      default = null;
      example = "/etc/restic/password.txt";
      description = "Path to the file containing the restic repository password";
    };

    onedriveConfigFile = mkOption {
      type = types.str;
      default = null;
      example = "/etc/restic/onedrive.conf";
      description = "Path to the rclone configuration file for OneDrive";
    };

    onedrivePath = mkOption {
      type = types.str;
      default = null;
      example = "/my/onedrive/destination";
      description = "Path in your OneDrive";
    };
  };

  config = mkIf cfg.enable {
    services = {
      resticBackup = {
        enable = true;
        paths = config.options.backup;
        passwordFile = config.options.resticPasswordFile;
        repository = "onedrive:${config.options.onedriveConfigFile}:${config.options.onedrivePath}";
        initialize = true; # initializes the repo, don't set if you want manual control
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
        # Additional restic configuration can be added here
      };
    };
  };
}
