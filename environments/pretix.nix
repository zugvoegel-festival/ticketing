{ ... }:
{
  # Pretix production — app-image bumped by pretix-v*.*.* tag CI or manual edit
  zugvoegel.services.pretix = {
    host = "tickets.zugvoegelfestival.org";
    instanceName = "Zugvoegel Ticketshop";
    # Exists on Docker Hub / host today; immutable pretix-v* tags via ticketing CI later.
    pretixImage = "manulinger/zv-ticketing:pretix";
    acmeMail = "webmaster@zugvoegelfestival.org";
    pretixDataPath = "/var/lib/pretix-data/data";
    port = 12345;
  };
}
