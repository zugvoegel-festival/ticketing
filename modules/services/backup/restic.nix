{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    backup = mkOption {
      type = types.listOf types.string;
      default = [ ];
      example = [ "/path/to/backup/directory" ];
      description = "Directories to be backed up using restic";
    };

    resticPasswordFile = mkOption {
      type = types.string;
      default = "";
      example = "/etc/restic/password.txt";
      description = "Path to the file containing the restic repository password";
    };

    onedriveConfigFile = mkOption {
      type = types.string;
      default = "";
      example = "/etc/restic/onedrive.conf";
      description = "Path to the rclone configuration file for OneDrive";
    };

    onedrivePath = mkOption {
      type = types.string;
      default = "";
      example = "/my/onedrive/destination";
      description = "Path in your OneDrive";
    };
  };

  config = {
    services = {
      resticBackup = {
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
