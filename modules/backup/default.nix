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

    sops.secrets.backup-envfile = { };
    sops.secrets.backup-passwordfile = { };

    services.restic.backups =
      let
        # host = config.networking.hostName;
        restic-ignore-file = pkgs.writeTextFile {
          name = "
        restic-ignore-file ";
          text = builtins.concatStringsSep "\
            n "
            cfg.backup-paths-exclude;
        };
      in
      {
        s3-offsite = {
          paths = cfg.backupDirs;
          repository = " s3:https://s3.us-west-004.backblazeb2.com/zugvoegelticketingbkp ";
          environmentFile = config.sops.secrets.backup-envfile.path;
          passwordFile = config.sops.secrets.backup-passwordfile.path;
          backupPrepareCommand = '' ${pkgs.postgresql}/bin/pg_dumpall -U postgres -h postgresql > "$(date + "%Y-%m-%d").sql " '';
          backupCleanupCommand = '' rm "$(date + "%Y-%m-%d").sql " '';
          timerConfig =
            {
              OnCalendar = "00:05";
              Persistent = true;
              RandomizedDelaySec = "5h";
            };
          extraBackupArgs = [
            " - -exclude-file = ${restic-ignore-file}"
            " - -one-file-system "
            # " - -dry-run "
            " - vv "
          ];
        };

      };
  };
}





