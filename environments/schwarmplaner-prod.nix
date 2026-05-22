{ ... }:
{
  # Schwarmplaner production — app-image bumped by schwarmplaner release-prod.sh
  zugvoegel.services.schwarmplaner.instances.prod = {
    host = "schwarmplaner.zugvoegelfestival.org";
    app-image = "manulinger/schwarmplaner:0.1.6";
    acmeMail = "webmaster@zugvoegelfestival.org";
    port = 3303;
  };
}
