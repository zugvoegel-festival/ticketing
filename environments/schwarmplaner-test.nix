{ ... }:
{
  # Schwarmplaner test — app-image bumped by schwarmplaner release-test.sh
  zugvoegel.services.schwarmplaner.instances.test = {
    host = "test.schwarmplaner.zugvoegelfestival.org";
    app-image = "manulinger/schwarmplaner:test-latest";
    acmeMail = "webmaster@zugvoegelfestival.org";
    port = 3313;
  };
}
