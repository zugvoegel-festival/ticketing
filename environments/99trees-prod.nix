{ ... }:
{
  # 99trees production only — app-image bumped by 99trees release-prod.sh
  zugvoegel.services.trees99.instances.prod = {
    host = "trees.loco.vision";
    app-image = "manulinger/99trees:1.0.4";
    acmeMail = "webmaster@zugvoegelfestival.org";
    port = 3323;
  };
}
