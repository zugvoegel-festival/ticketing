{
  description = "Pretix flake configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    bank-automation.url = "github:zugvoegel-festival/pretix-bank-automation";

    # Partitioning
    disko.url = "github:nix-community/disko";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Use `nix flake show` to view outputs
  outputs = { self, nixpkgs, disko, sops-nix, bank-automation }@inputs: {

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
        specialArgs = inputs;
        modules = [
          ./configuration.nix
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          { imports = builtins.attrValues self.nixosModules; }
        ];
      };
    };
  };
}
