# Ticketing Deployment using Pretix on NixOS

The following was tested on [netcup](https://netcup.de) using a `VPS 500 G10s`
server. Other providers or server variants will probably work too, but are
untested at this point.

After booking the `VPS 500 G10s` you will get an e-mail with the root
credentials and a `debian-minimal` image preinstalled. 

### Initial deployment (Server is still other OS)

Setup public-key based authentication on the server and run nixos-anywhere for
intial deployment. The public key will persist after infection.

```
ssh-copy-id -o PubkeyAuthentication=no -o PreferredAuthentications=password  root@185.232.69.172
ssh root@185.232.69.172
nix run github:numtide/nixos-anywhere -- --flake .\#pretix-server-01 root@185.232.69.172
```

### Further deployments (Server is NixOS)

You now have a NixOS server and can deploy this demo. You might want to set DNS
records if you have a domain and configure the nginx virtual host accordingly,
otherwise deployment will still work, but you won't get SSL certificates
generated as the DNS challenge will fail.

Further deployments can be done with:

```sh
nix-shell -p nixos-rebuild 

nixos-rebuild switch --flake '.#pretix-server-01' --target-host root@185.232.69.172  --build-host root@185.232.69.172 
```

Note: Other deployment methods are possible and might be more suitable for
multiple servers.
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) is used here
for simplicity. Other options are using a deployment tool like
[lollypops](https://github.com/pinpox/lollypops) or uploading a pre-backed
`.qcow2` image, which can be generated from a flake.

### Secrets management

Secrets are encrypted and managed with [sops-nix](https://github.com/Mic92/sops-nix)

```sh
nix-shell -p sops --run "sops secrets/secrets.yaml"
```
