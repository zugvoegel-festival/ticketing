{ lib, pkgs, config, ... }:
with lib;
let cfg = config.zugvoegel.services.backup;
in
{
  options.zugvoegel.services.backup = {
    enable = mkEnableOption "restic backups";

    backupDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/home/zugvoegel/Notes" ];
      description = "Paths to backup to offsite storage";
    };

    backup-paths-exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/home/zugvoegel/cache" ];
      description = "Paths to exclude from backup";
    };
  };

  config = mkIf cfg.enable {

    services.restic.backups =
      let
        # host = config.networking.hostName;
        restic-ignore-file = pkgs.writeTextFile {
          name = "restic-ignore-file";
          text = builtins.concatStringsSep "\n" cfg.backup-paths-exclude;
        };
      in
      {
        s3-offsite = {
          paths = cfg.backupDirs;
          repository = "s3:https://s3.us-west-004.backblazeb2.com/zugvoegelticketingbkp";
          environmentFile = "/var/secrets/backblaze-credentials";
          passwordFile = "/var/secrets/restic";

          extraBackupArgs = [
            "--exclude-file=${restic-ignore-file}"
            "--one-file-system"
            # "--dry-run"
            "-vv"
          ];
        };
      };
  };
}
