{
  description = "Pretix flake configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
  };

  # Use `nix flake show` to view outputs
  outputs = { self, nixpkgs, disko }: {

    # Output all modules in ./modules to flake. Modules should be in
    # individual subdirectories and contain a default.nix file
    nixosModules = builtins.listToAttrs (map
      (x: {
        name = x;
        value = import (./modules + "/${x}");
      })
      (builtins.attrNames (builtins.readDir ./modules)));

    # Define system configurations
    nixosConfigurations = {
      pretix-server-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          disko.nixosModules.disko
          { imports = builtins.attrValues self.nixosModules; }
        ];
      };
    };
  };
}
