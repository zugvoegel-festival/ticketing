{ lib, pkgs, config, ... }:
with lib;
let cfg = config.zugvoegel.services.backup;
in
{
  options.zugvoegel.services.backup = {
    enable = mkEnableOption "restic backups";

    postgresDumpPath = mkOption {
      type = types.str;
      default = "/var/lib/pretix-postgresql/dumps";
      example = "/var/lib/backups";
      description = "Path to use to dump sql for backups";
    };

    mysqlDumpPath = mkOption {
      type = types.str;
      default = "/var/lib/schwarmplaner/dumps";
      example = "/var/lib/backups";
      description = "Path to use to dump sql for backups";
    };

    backupDirs = mkOption {
      type = types.listOf types.str;
      default = [ config.zugvoegel.services.backup.postgresDumpPath ];
      example = [ "/home/zugvoegel/Notes" ];
      description = "Paths to backup to offsite storage";
    };

    backup-paths-exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/home/zugvoegel/cache" ];
      description = "Paths to exclude from backup";
    };

    s3Repository = mkOption {
      type = types.listOf types.str;
      default = [ "s3:https://s3.us-west-004.backblazeb2.com/zugvoegelticketingbkp" ];
      example = [ "s3:https://s3.us-west-004.backblazeb2.com/zugvoegelticketingbkp" ];
      description = "s3 repository";
    };
  };


  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ restic ];

    sops.secrets.backup-envfile = { };
    sops.secrets.backup-passwordfile = { };

    systemd.services.restic-backups-zv-data.preStart =
      ''
        mkdir -p "${cfg.postgresDumpPath}"
        mkdir -p "${cfg.mysqlDumpPath}"
      '';

    services.restic.backups =
      let
        # host = config.networking.hostName;
        restic-ignore-file = pkgs.writeTextFile {
          name = "restic-ignore-file";
          text = builtins.concatStringsSep "\n"
            cfg.backup-paths-exclude;
        };
      in
      {
        zv-data = {
          paths = cfg.backupDirs;
          repository = "s3:https://s3.us-west-004.backblazeb2.com/zugvoegelticketingbkp";
          environmentFile = config.sops.secrets.backup-envfile.path;
          passwordFile = config.sops.secrets.backup-passwordfile.path;
          backupPrepareCommand = ''
            ${config.virtualisation.docker.package}/bin/docker exec postgresql pg_dumpall -U postgres -h postgresql > ${cfg.postgresDumpPath}/dump_"$(date +"%Y-%m-%d").sql"
            ${config.virtualisation.docker.package}/bin/docker exec schwarmplaner-db mysqldump -u root -pHurraWirFliegen24 schwarmDatabase > ${cfg.mysqlDumpPath}/dump_"$(date +"%Y-%m-%d").sql"
          '';
          backupCleanupCommand = ''
            rm "${cfg.postgresDumpPath}/dump_$(date +"%Y-%m-%d").sql"
            rm "${cfg.mysqlDumpPath}/dump_$(date +"%Y-%m-%d").sql"
          '';
          timerConfig =
            {
              OnCalendar = "00:05";
              Persistent = true;
              RandomizedDelaySec = "5h";
            };
          extraBackupArgs = [
            "--exclude-file=${restic-ignore-file}"
            "--one-file-system"
            "-vv"
          ];
        };
      };
  };
}
