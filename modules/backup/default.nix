{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.zugvoegel.services.backup;
in
{
  options.zugvoegel.services.backup = {
    enable = mkEnableOption "restic backups";

    s3BaseUrl = mkOption {
      type = types.str;
      default = "s3:https://s3.us-west-004.backblazeb2.com";
      description = "Base S3 URL for backup repositories";
    };

    bucketPrefix = mkOption {
      type = types.str;
      default = "zugvoegel";
      description = "Prefix for S3 bucket names";
    };

    schedule = mkOption {
      type = types.str;
      default = "03:00";
      description = "Default backup schedule (systemd calendar format)";
    };

    services = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable backup for this service";
            };

            type = mkOption {
              type = types.enum [
                "database"
                "files"
              ];
              description = "Type of backup: database dump or file backup";
            };

            schedule = mkOption {
              type = types.str;
              default = cfg.schedule;
              description = "Backup schedule for this service (systemd calendar format)";
            };

            paths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Paths to backup (for file backups)";
            };

            excludePaths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Paths to exclude from backup";
            };

            # Database specific options
            dbType = mkOption {
              type = types.nullOr (
                types.enum [
                  "postgresql"
                  "mysql"
                ]
              );
              default = null;
              description = "Database type for database backups";
            };

            containerName = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Docker container name for database backups";
            };

            dbName = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Database name (for MySQL)";
            };

            dbUser = mkOption {
              type = types.str;
              default =
                if (cfg.services ? dbType && cfg.services.dbType == "postgresql") then "postgres" else "root";
              description = "Database user";
            };

            dbPassword = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Database password (for MySQL)";
            };

            dumpPath = mkOption {
              type = types.str;
              default = "/var/lib/backups/${name}";
              description = "Path where database dumps are stored";
            };
          };
        }
      );
      default = { };
      description = "Services to backup";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ restic ];

    sops.secrets.backup-envfile = { };
    sops.secrets.backup-passwordfile = { };

    services.restic.backups =
      let
        # Create a backup configuration for each enabled service
        createBackup =
          serviceName: serviceConfig:
          let
            repository = "${cfg.s3BaseUrl}/zugvoegelticketingbkp/${serviceName}";

            # Create exclude file if paths are specified
            excludeFile =
              if serviceConfig.excludePaths != [ ] then
                pkgs.writeTextFile {
                  name = "${serviceName}-exclude-file";
                  text = builtins.concatStringsSep "\n" serviceConfig.excludePaths;
                }
              else
                null;

            # Database dump commands
            dbCommands =
              if serviceConfig.type == "database" then
                let
                  dumpDir = serviceConfig.dumpPath;
                  timestamp = ''$(date +"%Y-%m-%d_%H-%M-%S")'';
                in
                if serviceConfig.dbType == "postgresql" then
                  ''
                    mkdir -p "${dumpDir}"
                    ${config.virtualisation.docker.package}/bin/docker exec ${serviceConfig.containerName} pg_dumpall -U ${serviceConfig.dbUser} > ${dumpDir}/dump_${timestamp}.sql
                  ''
                else if serviceConfig.dbType == "mysql" then
                  ''
                    mkdir -p "${dumpDir}"
                    ${config.virtualisation.docker.package}/bin/docker exec ${serviceConfig.containerName} mysqldump -u ${serviceConfig.dbUser} ${
                      if serviceConfig.dbPassword != null then "-p${serviceConfig.dbPassword}" else ""
                    } ${serviceConfig.dbName} > ${dumpDir}/dump_${timestamp}.sql
                  ''
                else
                  ""
              else
                "";

            # Cleanup commands for database dumps
            cleanupCommands =
              if serviceConfig.type == "database" then
                ''
                  # Keep only the 3 most recent dumps
                  cd ${serviceConfig.dumpPath} && ls -t dump_*.sql | tail -n +4 | xargs -r rm
                ''
              else
                "";

            # Paths to backup
            backupPaths =
              if serviceConfig.type == "database" then [ serviceConfig.dumpPath ] else serviceConfig.paths;
          in
          nameValuePair serviceName {
            inherit repository;
            paths = backupPaths;
            environmentFile = config.sops.secrets.backup-envfile.path;
            passwordFile = config.sops.secrets.backup-passwordfile.path;

            backupPrepareCommand = dbCommands;
            backupCleanupCommand = cleanupCommands;

            timerConfig = {
              OnCalendar = serviceConfig.schedule;
              Persistent = true;
              RandomizedDelaySec = "1h";
            };

            extraBackupArgs = [
              "--tag"
              serviceName
              "--one-file-system"
              "-v"
            ] ++ (if excludeFile != null then [ "--exclude-file=${excludeFile}" ] else [ ]);
          };

        # Filter enabled services and create backup configs
        enabledServices = lib.filterAttrs (_: serviceConfig: serviceConfig.enable) cfg.services;
      in
      builtins.listToAttrs (lib.mapAttrsToList createBackup enabledServices);
  };
}
