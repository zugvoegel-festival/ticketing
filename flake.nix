{
  description = "Pretix flake configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Partitioning
    disko.url = "github:nix-community/disko";

    # Secrets management
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "";

  };

  # Use `nix flake show` to view outputs
  outputs = { self, nixpkgs, disko, agenix }: {

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
          agenix.nixosModules.default
          self.nixosModules.pretix # Import our module
        ];
      };
    };
  };
}
