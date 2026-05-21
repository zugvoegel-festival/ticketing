{ ... }:
{
  # Pretix production — app-image bumped by pretix release-prod.sh or manual edit
  zugvoegel.services.pretix = {
    host = "tickets.zugvoegelfestival.org";
    instanceName = "Zugvoegel Ticketshop";
    # Exists on Docker Hub / host today; immutable tags via pretix repo v* CI.
    pretixImage = "manulinger/zv-ticketing:pretix";
    acmeMail = "webmaster@zugvoegelfestival.org";
    pretixDataPath = "/var/lib/pretix-data/data";
    port = 12345;
  };
}
