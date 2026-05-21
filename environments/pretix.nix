{ ... }:
{
  # Pretix production — app-image bumped by pretix-v*.*.* tag CI or manual edit
  zugvoegel.services.pretix = {
    host = "tickets.zugvoegelfestival.org";
    instanceName = "Zugvoegel Ticketshop";
    pretixImage = "manulinger/zv-ticketing:pretix-latest";
    acmeMail = "webmaster@zugvoegelfestival.org";
    pretixDataPath = "/var/lib/pretix-data/data";
    port = 12345;
  };
}
