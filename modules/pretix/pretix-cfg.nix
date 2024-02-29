{ cfg, pkgs, ... }:
pkgs.writeTextFile {
  name = "pretix.cfg";
  text = pkgs.lib.generators.toINI { } {
    pretix = {
      instance_name = "${cfg.instanceName}";
      url = "https://${cfg.host}";
      currency = "EUR";
      # ; DO NOT change the following value, it has to be set to the location of the
      # ; directory *inside* the docker container
      datadir = "/data";
      trust_x_forwarded_for = "on";
      trust_x_forwarded_proto = "on";
    };

    metrics = {
      enabled = true;
      user = "${cfg.metrics-user}";
      passphrase = "${cfg.metrics-password}"; # TODO @pablo how to add secrets from sops here?
    };
    database = {
      backend = "postgresql";
      name = "pretix";
      user = "postgres";
      host = "postgresql";
    };

    redis = {
      location = "redis://redis:6379";
      # ; Remove the following line if you are unsure about your redis' security
      # ; to reduce impact if redis gets compromised.
      sessions = "true";
    };

    celery = {
      backend = "redis://redis:6379/1";
      broker = "redis://redis:6379/2";
    };
  };
}
